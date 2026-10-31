import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Loại thông báo do Dart gửi. Mỗi loại có mức ưu tiên + thời gian nghỉ riêng
/// (xem [_KindRules]) để không bao giờ spam cùng 1 loại.
enum NotificationKind { eyeBreak, darkRoom, nightMode, distance, setup, update, tip }

extension _KindRules on NotificationKind {
  /// Số càng lớn càng quan trọng — quyết định tiêu đề khi gộp.
  int get priority => switch (this) {
        NotificationKind.eyeBreak => 4,
        NotificationKind.darkRoom => 3,
        NotificationKind.nightMode => 2,
        NotificationKind.distance => 2,
        NotificationKind.setup => 2,
        NotificationKind.update => 1,
        NotificationKind.tip => 1,
      };

  /// Sau khi 1 thông báo loại này được GỬI, chặn cùng loại trong khoảng này.
  Duration get cooldown => switch (this) {
        NotificationKind.eyeBreak => const Duration(minutes: 2),
        NotificationKind.darkRoom => const Duration(minutes: 30),
        NotificationKind.nightMode => const Duration(hours: 6),
        NotificationKind.distance => const Duration(minutes: 30),
        NotificationKind.setup => const Duration(hours: 24),
        NotificationKind.update => const Duration(hours: 24),
        NotificationKind.tip => const Duration(hours: 4),
      };
}

/// 1 yêu cầu thông báo. Nếu gửi ĐỘC LẬP thì dùng [soloShow] (nếu có, để giữ
/// giao diện riêng như nút hành động) hoặc [title]/[body]; nếu bị GỘP với loại
/// khác thì dùng [mergedTitle] (nếu có) và [mergeLine] làm 1 dòng trong nội dung.
class NotificationRequest {
  const NotificationRequest({
    required this.kind,
    required this.title,
    required this.body,
    this.mergeLine,
    this.mergedTitle,
    this.payload,
    this.soloShow,
  });

  final NotificationKind kind;
  final String title;
  final String body;
  final String? mergeLine;
  final String? mergedTitle;
  final String? payload;
  final Future<void> Function()? soloShow;
}

class _Pending {
  _Pending(this.request) : queuedAt = DateTime.now();
  final NotificationRequest request;
  final DateTime queuedAt;
}

/// Notification Intelligence Layer — mọi thông báo do Dart gửi nên đi qua đây
/// thay vì gọi thẳng NotificationService:
///  1. CHỐNG LẶP: cùng loại trong thời gian nghỉ -> bỏ.
///  2. GOM NHÓM: các yêu cầu đến trong [_batchWindow] được gộp thành 1 thông báo.
///  3. NÉ GIỜ NGHỈ MẮT: báo thức nghỉ mắt là native (không chặn/gộp được lúc nó
///     bắn) nên thông báo phụ được HOÃN nếu báo thức sắp/vừa bắn trong
///     [_eyeBreakWindow], tối đa [_maxDeferral].
///
/// GIỚI HẠN: chỉ điều phối thông báo do Dart gửi. Thông báo native tự bắn
/// (báo thức nghỉ mắt, nhắc hằng ngày/tuần, DarkRoomWorker.kt) vẫn đi thẳng ra
/// hệ điều hành.
class NotificationCoordinator {
  NotificationCoordinator._();
  static final NotificationCoordinator instance = NotificationCoordinator._();

  static const _batchWindow = Duration(seconds: 15);
  static const _eyeBreakWindow = Duration(minutes: 2);
  static const _maxDeferral = Duration(minutes: 6);
  static const _digestId = 3001;
  static const _lastDeliveredPrefix = 'notif_last_delivered_';
  // Trùng với khoá NotificationService lưu khoảng lặp của báo thức nghỉ mắt.
  static const _repeatIntervalKey = 'pref_break_repeat_interval_minutes';

  final List<_Pending> _pending = [];
  Timer? _timer;

  /// Gửi 1 yêu cầu thông báo qua lớp điều phối.
  Future<void> notify(NotificationRequest request) async {
    if (await _inCooldown(request.kind)) {
      debugPrint('[NotificationCoordinator] dropped ${request.kind.name}: cooldown');
      return;
    }
    // Cùng loại đang chờ -> thay bằng bản mới nhất, không xếp chồng.
    _pending.removeWhere((p) => p.request.kind == request.kind);
    _pending.add(_Pending(request));
    _timer?.cancel();
    _timer = Timer(_batchWindow, _flush);
  }

  Future<bool> _inCooldown(NotificationKind kind) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('$_lastDeliveredPrefix${kind.name}');
    if (last == null) return false;
    final since = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    return since < kind.cooldown;
  }

  Future<void> _flush() async {
    _timer = null;
    if (_pending.isEmpty) return;

    final hasEyeBreak = _pending.any((p) => p.request.kind == NotificationKind.eyeBreak);
    final oldest = _pending.map((p) => p.queuedAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final expired = DateTime.now().difference(oldest) >= _maxDeferral;

    if (!hasEyeBreak && !expired) {
      final wait = await _eyeBreakDeferral();
      if (wait != null) {
        debugPrint('[NotificationCoordinator] deferring ${wait.inSeconds}s around eye-break alarm');
        _timer = Timer(wait, _flush);
        return;
      }
    }

    final batch = List<_Pending>.of(_pending)
      ..sort((a, b) => b.request.kind.priority.compareTo(a.request.kind.priority));
    _pending.clear();
    await _deliver(batch.map((p) => p.request).toList());
  }

  // Thời gian cần hoãn nếu báo thức nghỉ mắt SẮP bắn hoặc VỪA bắn; null = không cần.
  Future<Duration?> _eyeBreakDeferral() async {
    final next = await NotificationService.instance.getNextRepeatingFireAt();
    if (next == null) return null; // không có báo thức nghỉ mắt nào đang chạy.

    final untilNext = next.difference(DateTime.now());
    if (untilNext <= _eyeBreakWindow) {
      // Sắp bắn: đợi nó bắn xong + thêm 1 khoảng đệm rồi mới gửi.
      return untilNext + _eyeBreakWindow;
    }

    final prefs = await SharedPreferences.getInstance();
    final intervalMin = prefs.getInt(_repeatIntervalKey) ?? 0;
    if (intervalMin > 0) {
      final sinceLast = Duration(minutes: intervalMin) - untilNext;
      if (sinceLast >= Duration.zero && sinceLast < _eyeBreakWindow) {
        return _eyeBreakWindow - sinceLast; // vừa bắn: đợi hết khoảng đệm.
      }
    }
    return null;
  }

  Future<void> _deliver(List<NotificationRequest> batch) async {
    if (batch.isEmpty) return;
    final top = batch.first; // đã sắp theo ưu tiên giảm dần.

    if (batch.length == 1) {
      if (top.soloShow != null) {
        await top.soloShow!();
      } else {
        await _show(top.title, top.body, top.payload);
      }
    } else {
      final title = top.mergedTitle ?? top.title;
      final body = batch.map((r) => r.mergeLine ?? r.body).join('\n');
      await _show(title, body, top.payload);
    }
    await _recordDelivered(batch.map((r) => r.kind));
  }

  Future<void> _recordDelivered(Iterable<NotificationKind> kinds) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final kind in kinds) {
      await prefs.setInt('$_lastDeliveredPrefix${kind.name}', now);
    }
  }

  // BigTextStyle để nội dung gộp nhiều dòng hiện đủ khi kéo xuống.
  Future<void> _show(String title, String body, String? payload) async {
    await NotificationService.instance.initialize();
    await NotificationService.instance.notifications.show(
      _digestId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'notification_digest',
          'Nhắc nhở & gợi ý',
          channelDescription: 'Cảnh báo ánh sáng và gợi ý chăm sóc mắt, đã được gộp để không bị spam',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }
}