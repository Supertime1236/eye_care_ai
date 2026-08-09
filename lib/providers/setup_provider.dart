import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/focus_mode_service.dart';
import '../services/usage_service.dart';
import '../utils/permission_helper.dart';

/// Từng bước quyền trong First-Time Setup Wizard, theo đúng thứ tự hiện ra.
/// Thứ tự có chủ đích: Usage Access trước tiên vì gần như MỌI tính năng cốt
/// lõi (thói quen Phone Usage, điểm sức khỏe mắt, thống kê, VÀ CẢ ước lượng
/// giấc ngủ — xem UsageStatsHandler.getSleepEstimate()) đều phụ thuộc vào
/// nó; các quyền còn lại bổ trợ cho từng thói quen/tính năng riêng lẻ.
///
/// BỎ bước `sleep` riêng (trước đây xin quyền Health Connect) — Sleep giờ
/// suy ra từ chính Usage Access ở trên, không cần quyền riêng nữa. THÊM 4
/// bước còn thiếu so với danh sách quyền thật ở màn Cài đặt (Settings ->
/// Quyền & dữ liệu): vị trí (outdoor time), nhận diện hoạt động (bước
/// chân/vận động), popup toàn màn hình lúc hết giờ nghỉ mắt, và chạy nền
/// không giới hạn (báo thức không bị trễ/im lặng do OEM diệt tiến trình).
enum SetupStepId {
  usageAccess,
  notifications,
  location,
  activityRecognition,
  fullScreenIntent,
  batteryOptimization,
  focusMode,
}

/// Theo dõi tiến độ First-Time Setup Wizard (đã hoàn tất/bỏ qua hẳn chưa) +
/// trạng thái CÒN SỐNG của từng quyền — vì quyền hệ thống có thể bị người
/// dùng bật/tắt lại bất cứ lúc nào ngoài luồng của app (trong Cài đặt máy),
/// nên KHÔNG lưu trạng thái "đã cấp" vào SharedPreferences, mà luôn hỏi lại
/// hệ thống mỗi lần refreshStatus() — chỉ mỗi việc "đã hoàn tất/bỏ qua
/// wizard lần đầu hay chưa" mới cần nhớ lâu dài (để không ép xem wizard lại
/// mỗi lần mở app).
class SetupProvider extends ChangeNotifier {
  static const _kWizardCompletedKey = 'pref_setup_wizard_completed';

  bool _wizardCompleted = false;
  bool get wizardCompleted => _wizardCompleted;

  bool _loading = true;
  bool get loading => _loading;

  final Map<SetupStepId, bool> _status = {
    for (final id in SetupStepId.values) id: false,
  };
  Map<SetupStepId, bool> get status => Map.unmodifiable(_status);

  int get grantedCount => _status.values.where((v) => v).length;
  int get totalCount => _status.length;
  bool get allGranted => grantedCount == totalCount;

  SetupProvider() {
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _wizardCompleted = prefs.getBool(_kWizardCompletedKey) ?? false;
    await refreshStatus();
    _loading = false;
    notifyListeners();
  }

  /// Nạp lại từ SharedPreferences — dùng sau khi CloudBackupService khôi
  /// phục dữ liệu tài khoản (không phục hồi trạng thái quyền hệ thống, vì
  /// quyền luôn gắn với THIẾT BỊ chứ không phải tài khoản — chỉ cần đọc lại
  /// cờ wizardCompleted).
  Future<void> reload() => _init();

  bool isGranted(SetupStepId id) => _status[id] ?? false;

  /// Hỏi lại HỆ THỐNG trạng thái từng quyền — gọi khi mở Wizard, khi quay lại
  /// app sau khi rời sang màn Cài đặt hệ thống, và định kỳ (MainShell) để
  /// banner ở Home luôn đúng thực tế.
  ///
  /// fullScreenIntent & batteryOptimization: Android KHÔNG có API công khai
  /// đọc được trạng thái 2 công tắc này (giống các tile tương ứng ở màn
  /// Cài đặt) — luôn coi là "đã cấp" (true), tile chỉ mang tính "Quản lý"
  /// để mở đúng màn cài đặt cho người dùng tự kiểm tra/bật tay.
  Future<void> refreshStatus() async {
    final results = await Future.wait<bool>([
      UsageService.hasPermission(),
      Platform.isAndroid
          ? Permission.notification.status.then((s) => s.isGranted)
          : Future.value(true),
      PermissionHelper.checkLocationPermission(),
      PermissionHelper.checkActivityPermission(),
      FocusModeService.instance.hasAccess(),
    ]);
    _status[SetupStepId.usageAccess] = results[0];
    _status[SetupStepId.notifications] = results[1];
    _status[SetupStepId.location] = results[2];
    _status[SetupStepId.activityRecognition] = results[3];
    _status[SetupStepId.fullScreenIntent] = true;
    _status[SetupStepId.batteryOptimization] = true;
    _status[SetupStepId.focusMode] = results[4];
    notifyListeners();
  }

  Future<void> markWizardCompleted() async {
    _wizardCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWizardCompletedKey, true);
    notifyListeners();
  }
}