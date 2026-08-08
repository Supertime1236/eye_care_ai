import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sao lưu/khôi phục dữ liệu app (thống kê, cài đặt, tiến độ thành tựu...)
/// theo TÀI KHOẢN đang đăng nhập (Gmail hoặc email/password), để khi người
/// dùng cài lại app hoặc đổi máy, đăng nhập lại đúng tài khoản thì mọi thứ
/// trở về y như cũ — thay vì mất sạch vì toàn bộ dữ liệu trước giờ chỉ nằm
/// trong SharedPreferences (chỉ sống trên MÁY, mất khi gỡ cài đặt).
///
/// Cách làm: mọi cài đặt/thống kê trong app đều đã được lưu qua
/// SharedPreferences với tên key có TIỀN TỐ rõ ràng (pref_*, eye_breaks_*,
/// daily_snapshot_*...) — thay vì phải map thủ công từng field của từng
/// provider (rất dễ sót mỗi khi có provider mới), backup này đọc THẲNG toàn
/// bộ key khớp các tiền tố đó rồi đẩy nguyên lên Firestore theo UID. Khôi
/// phục thì làm ngược lại: ghi thẳng các key đó vào SharedPreferences rồi
/// yêu cầu từng provider tự nạp lại (xem reload() ở mỗi provider).
class CloudBackupService {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  // CHỈ backup các key khớp 1 trong các tiền tố này — đây đều là dữ liệu
  // "có ý nghĩa lâu dài" (cài đặt, thống kê, tiến độ) — KHÔNG gồm các key
  // nội bộ dùng cho notification/timer đang chạy dở (không có ý nghĩa gì khi
  // khôi phục sang phiên làm việc khác).
  static const List<String> _backupPrefixes = [
    'pref_', // mọi tuỳ chọn: theme, ngôn ngữ, đơn vị đo, target habit, accent color, font, reminder...
    'eye_breaks_', // số lần nghỉ mắt hôm nay + tổng cộng dồn (dùng cho Thành tựu)
    'daily_snapshot_', // snapshot điểm số/screen time/sleep từng ngày (dùng tính streak + biểu đồ Thống kê)
    'outdoor_minutes_',
    'reading_minutes_',
    'survey_completed',
    'consent_given',
    'consent_timestamp',
    'data_collection_enabled',
  ];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('user_backups').doc(uid);
  }

  bool _matchesBackupPrefix(String key) => _backupPrefixes.any(key.startsWith);

  /// Đẩy toàn bộ dữ liệu cục bộ (khớp whitelist ở trên) lên Firestore. Gọi
  /// định kỳ + khi app xuống nền (xem MainShell) — KHÔNG await/chặn UI vì
  /// đây luôn là việc chạy nền, lỗi mạng không được ảnh hưởng trải nghiệm.
  Future<void> pushBackup() async {
    final doc = _doc;
    if (doc == null) return; // Chưa đăng nhập -> không có nơi để lưu, bỏ qua âm thầm.

    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (!_matchesBackupPrefix(key)) continue;
      final value = prefs.get(key);
      if (value is bool || value is int || value is double || value is String) {
        data[key] = value;
      }
      // (App không dùng List<String> cho các key thuộc whitelist này nên
      // không cần xử lý riêng StringList.)
    }
    data['_updatedAt'] = FieldValue.serverTimestamp();

    try {
      await doc.set(data, SetOptions(merge: true));
    } catch (_) {
      // Mất mạng/chưa bật Firestore... -> im lặng bỏ qua, thử lại ở lần đẩy kế tiếp.
    }
  }

  /// Tải dữ liệu đã sao lưu (nếu có) và ghi thẳng vào SharedPreferences cục
  /// bộ — gọi ngay sau khi đăng nhập thành công, TRƯỚC khi vào MainShell.
  /// Trả về true nếu có dữ liệu và đã áp dụng (để nơi gọi biết mà refresh
  /// lại các provider đang cầm dữ liệu cũ trong bộ nhớ).
  Future<bool> pullAndApply() async {
    final doc = _doc;
    if (doc == null) return false;

    Map<String, dynamic>? remote;
    try {
      final snapshot = await doc.get().timeout(const Duration(seconds: 8));
      remote = snapshot.data();
    } catch (_) {
      return false; // Mất mạng hoặc chưa từng sao lưu -> giữ nguyên dữ liệu máy hiện có.
    }
    if (remote == null || remote.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    var appliedAny = false;
    for (final entry in remote.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == '_updatedAt' || !_matchesBackupPrefix(key)) continue;
      if (value is bool) {
        await prefs.setBool(key, value);
        appliedAny = true;
      } else if (value is int) {
        await prefs.setInt(key, value);
        appliedAny = true;
      } else if (value is double) {
        await prefs.setDouble(key, value);
        appliedAny = true;
      } else if (value is num) {
        // Firestore có thể trả int gốc thành double hoặc ngược lại tuỳ SDK
        // -> ưu tiên giữ nguyên kiểu double an toàn cho mọi trường hợp số.
        await prefs.setDouble(key, value.toDouble());
        appliedAny = true;
      } else if (value is String) {
        await prefs.setString(key, value);
        appliedAny = true;
      }
    }
    return appliedAny;
  }

  /// Xoá hẳn bản sao lưu trên Firestore — gọi khi người dùng xoá tài khoản,
  /// vì UID cũ sẽ không bao giờ đăng nhập lại được nữa (tránh để dữ liệu
  /// mồ côi trong Firestore mãi mãi).
  Future<void> deleteBackup() async {
    final doc = _doc;
    if (doc == null) return;
    try {
      await doc.delete();
    } catch (_) {
      // Không có mạng lúc xoá tài khoản -> bỏ qua, không được chặn việc xoá
      // tài khoản (quan trọng hơn) chỉ vì dọn dẹp backup thất bại.
    }
  }
}
