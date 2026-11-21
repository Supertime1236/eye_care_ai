import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../services/focus_mode_service.dart';
import '../services/notification_service.dart';
import '../services/usage_service.dart';
import '../theme/app_colors.dart';
import '../utils/permission_helper.dart';
import '../widgets/shared_widgets.dart';

enum _Level { ok, needed, optional }

class _Check {
  const _Check({
    required this.icon,
    required this.title,
    required this.powers,
    required this.level,
    required this.granted,
    required this.fixLabel,
    required this.onFix,
  });

  final IconData icon;
  final String title;

  /// Những tính năng phụ thuộc vào mục này — để người dùng hiểu "vì sao cần".
  final String powers;
  final _Level level;
  final bool granted;
  final String fixLabel;
  final Future<void> Function() onFix;
}

/// "Kiểm tra hoạt động": liệt kê từng quyền/cài đặt hệ thống mà các tính năng
/// của app phụ thuộc vào, cho biết đang bật hay thiếu, tính năng nào bị ảnh
/// hưởng, và có nút sửa ngay. Nhiều tính năng (thời gian ngoài trời, giấc ngủ,
/// thống kê tháng, nhắc nghỉ mắt đúng giờ...) sẽ âm thầm không chạy nếu thiếu 1
/// quyền — màn này giúp tìm ra đúng chỗ thiếu thay vì phải đoán.
class FeatureHealthScreen extends StatefulWidget {
  const FeatureHealthScreen({super.key});

  @override
  State<FeatureHealthScreen> createState() => _FeatureHealthScreenState();
}

class _FeatureHealthScreenState extends State<FeatureHealthScreen> with WidgetsBindingObserver {
  List<_Check>? _checks;
  bool _vi = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _vi = context.read<LanguageProvider>().isVietnamese;
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Quay lại từ màn Cài đặt hệ thống -> kiểm tra lại ngay.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<bool> _safe(Future<bool> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return false;
    }
  }

  Future<void> _refresh() async {
    final vi = _vi;
    final results = await Future.wait<bool>([
      _safe(UsageService.hasPermission),
      _safe(() async => (await Permission.notification.status).isGranted),
      _safe(() async => (await Permission.location.status).isGranted),
      _safe(PermissionHelper.checkBackgroundLocationPermission),
      _safe(() async => (await Permission.camera.status).isGranted),
      _safe(FocusModeService.instance.hasAccess),
      _safe(NotificationService.instance.canScheduleExactAlarms),
      _safe(() async => (await Permission.ignoreBatteryOptimizations.status).isGranted),
    ]);

    final checks = <_Check>[
      _Check(
        icon: Icons.bar_chart_outlined,
        title: vi ? 'Truy cập dữ liệu sử dụng' : 'Usage access',
        powers: vi
            ? 'Thời gian màn hình, ước lượng giấc ngủ, điểm sức khỏe mắt, dùng điện thoại ban đêm, thống kê tháng'
            : 'Screen time, sleep estimate, eye health score, night phone usage, monthly stats',
        level: _Level.needed,
        granted: results[0],
        fixLabel: vi ? 'Cấp quyền' : 'Grant',
        onFix: PermissionHelper.openUsageAccessSettings,
      ),
      _Check(
        icon: Icons.notifications_outlined,
        title: vi ? 'Thông báo' : 'Notifications',
        powers: vi
            ? 'Nhắc nghỉ mắt, nhắc giữ chuỗi ngày, cảnh báo phòng tối'
            : 'Eye break reminders, streak reminders, dark-room warnings',
        level: _Level.needed,
        granted: results[1],
        fixLabel: vi ? 'Bật thông báo' : 'Enable',
        onFix: () => NotificationService.instance.requestNotificationPermission().then((_) {}),
      ),
      _Check(
        icon: Icons.alarm_outlined,
        title: vi ? 'Báo thức chính xác' : 'Exact alarms',
        powers: vi
            ? 'Thông báo nghỉ mắt bắn đúng giờ thay vì trễ vài phút'
            : 'Eye break notifications fire on time instead of minutes late',
        level: _Level.needed,
        granted: results[6],
        fixLabel: vi ? 'Mở cài đặt' : 'Open settings',
        onFix: NotificationService.instance.openExactAlarmSettings,
      ),
      _Check(
        icon: Icons.battery_charging_full_outlined,
        title: vi ? 'Chạy nền không giới hạn' : 'Unrestricted background',
        powers: vi
            ? 'Nhắc nghỉ mắt và đo thời gian ngoài trời khi app đã đóng. Máy Xiaomi/Redmi cần bật thêm "Tự khởi động" và khoá app ở màn hình ứng dụng gần đây.'
            : 'Eye break reminders and outdoor tracking while the app is closed. Xiaomi/Redmi phones also need "Autostart" and the app locked in recent apps.',
        level: _Level.needed,
        granted: results[7],
        fixLabel: vi ? 'Cho phép' : 'Allow',
        onFix: NotificationService.instance.requestIgnoreBatteryOptimizations,
      ),
      _Check(
        icon: Icons.location_on_outlined,
        title: vi ? 'Vị trí (khi đang dùng app)' : 'Location (while using the app)',
        powers: vi ? 'Thời gian ngoài trời khi app đang mở' : 'Outdoor time while the app is open',
        level: _Level.needed,
        granted: results[2],
        fixLabel: vi ? 'Cấp quyền' : 'Grant',
        onFix: () => PermissionHelper.requestLocationPermission().then((_) {}),
      ),
      _Check(
        icon: Icons.my_location_outlined,
        title: vi ? 'Vị trí "Luôn cho phép"' : 'Location "All the time"',
        powers: vi
            ? 'Tự ghi nhận thời gian ngoài trời kể cả khi app đã đóng — không cần mở app'
            : 'Tracks outdoor time even when the app is closed — no need to open it',
        level: _Level.optional,
        granted: results[3],
        fixLabel: vi ? 'Mở cài đặt' : 'Open settings',
        onFix: () async {
          final status = await Permission.locationAlways.request();
          if (!status.isGranted) await openAppSettings();
        },
      ),
      _Check(
        icon: Icons.videocam_outlined,
        title: vi ? 'Camera' : 'Camera',
        powers: vi
            ? 'Chỉ cần khi bật "Nhắc giữ khoảng cách" hoặc làm bài Kiểm tra mắt. Ảnh không được lưu hay gửi đi.'
            : 'Only needed for "Distance reminder" or the Eye Test. Images are never saved or sent.',
        level: _Level.optional,
        granted: results[4],
        fixLabel: vi ? 'Cấp quyền' : 'Grant',
        onFix: () async {
          final status = await Permission.camera.request();
          if (!status.isGranted) await openAppSettings();
        },
      ),
      _Check(
        icon: Icons.do_not_disturb_on_outlined,
        title: vi ? 'Không làm phiền (Chế độ Focus)' : 'Do Not Disturb (Focus mode)',
        powers: vi
            ? 'Chỉ cần nếu bạn muốn chặn thông báo app khác trong lúc đếm ngược nghỉ mắt'
            : 'Only needed if you want to silence other apps during the eye break countdown',
        level: _Level.optional,
        granted: results[5],
        fixLabel: vi ? 'Cấp quyền' : 'Grant',
        onFix: FocusModeService.instance.openAccessSettings,
      ),
    ];

    if (!mounted) return;
    setState(() => _checks = checks);
  }

  @override
  Widget build(BuildContext context) {
    final vi = context.watch<LanguageProvider>().isVietnamese;
    final checks = _checks;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: vi ? 'Quay lại' : 'Back',
        ),
        title: Text(vi ? 'Kiểm tra hoạt động' : 'Health check'),
      ),
      body: SafeArea(
        child: checks == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  children: [
                    _summary(context, checks, vi),
                    const SizedBox(height: 14),
                    for (final c in checks) ...[
                      _CheckCard(check: c, vi: vi, onChanged: _refresh),
                      const SizedBox(height: 10),
                    ],
                    Text(
                      vi
                          ? 'Mục "Tuỳ chọn" không bắt buộc — chỉ cần khi bạn dùng tính năng tương ứng.'
                          : '"Optional" items are not required — only needed for the matching feature.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _summary(BuildContext context, List<_Check> checks, bool vi) {
    final needed = checks.where((c) => c.level == _Level.needed).toList();
    final ready = needed.where((c) => c.granted).length;
    final allReady = ready == needed.length;
    final color = allReady ? AppColors.success : AppColors.warning;

    return SectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), shape: BoxShape.circle),
            child: Icon(
              allReady ? Icons.check_rounded : Icons.error_outline_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allReady
                      ? (vi ? 'Mọi thứ đã sẵn sàng' : 'Everything is ready')
                      : (vi ? 'Một số tính năng chưa chạy đủ' : 'Some features are not fully working'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  vi
                      ? '$ready/${needed.length} mục cần thiết đã bật'
                      : '$ready/${needed.length} required items are on',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatefulWidget {
  const _CheckCard({required this.check, required this.vi, required this.onChanged});

  final _Check check;
  final bool vi;
  final Future<void> Function() onChanged;

  @override
  State<_CheckCard> createState() => _CheckCardState();
}

class _CheckCardState extends State<_CheckCard> {
  bool _busy = false;

  Future<void> _fix() async {
    setState(() => _busy = true);
    try {
      await widget.check.onFix();
    } finally {
      if (mounted) setState(() => _busy = false);
      await widget.onChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.check;
    final vi = widget.vi;
    final Color color;
    final String label;
    if (c.granted) {
      color = AppColors.success;
      label = vi ? 'Đã bật' : 'On';
    } else if (c.level == _Level.needed) {
      color = AppColors.warning;
      label = vi ? 'Cần bật' : 'Needs action';
    } else {
      color = AppColors.textMuted;
      label = vi ? 'Tuỳ chọn' : 'Optional';
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(c.icon, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(c.title, style: Theme.of(context).textTheme.titleSmall)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(c.powers, style: Theme.of(context).textTheme.bodySmall),
          if (!c.granted) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: _busy ? null : _fix,
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(c.fixLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}