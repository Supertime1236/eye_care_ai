import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/auth_service.dart';

/// State cho màn hình "Cài đặt thêm" (Settings > More): quyền riêng tư,
/// bảo mật, quản lý dữ liệu, đăng xuất, xóa tài khoản.
///
/// LƯU Ý: file này KHÔNG trùng với `settings_provider.dart` (đơn vị đo,
/// định dạng giờ, thông báo) — được đặt tên riêng `SettingsMoreProvider`
/// để tránh xung đột, và được đăng ký thêm trong main.dart.
class SettingsMoreProvider extends ChangeNotifier {
  // ---- Privacy toggles ----
  bool _dataCollection = true;
  bool _cloudBackup = true;
  bool _personalizedAI = false;

  bool get dataCollection => _dataCollection;
  bool get cloudBackup => _cloudBackup;
  bool get personalizedAI => _personalizedAI;

  void setDataCollection(bool v) {
    _dataCollection = v;
    notifyListeners();
  }

  void setCloudBackup(bool v) {
    _cloudBackup = v;
    notifyListeners();
  }

  void setPersonalizedAI(bool v) {
    _personalizedAI = v;
    notifyListeners();
  }

  // ---- Security toggles ----
  bool _biometricLogin = false;
  bool _twoFactorAuth = false;
  final bool _biometricSupported = true;

  bool get biometricLogin => _biometricLogin;
  bool get twoFactorAuth => _twoFactorAuth;
  bool get biometricSupported => _biometricSupported;

  void setBiometricLogin(bool v) {
    _biometricLogin = v;
    notifyListeners();
  }

  void setTwoFactorAuth(bool v) {
    _twoFactorAuth = v;
    notifyListeners();
  }

  /// Đổi mật khẩu thật qua Firebase (AuthService.changePassword).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return AuthService.instance.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  // ---- Data management ----
  bool _isExporting = false;
  bool _isDeletingLocal = false;
  bool _isDeletingAccount = false;

  bool get isExporting => _isExporting;
  bool get isDeletingLocal => _isDeletingLocal;
  bool get isDeletingAccount => _isDeletingAccount;

  /// TODO: nối vào backend export dữ liệu thật khi có API.
  Future<void> exportMyData() async {
    _isExporting = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    _isExporting = false;
    notifyListeners();
  }

  /// TODO: sinh báo cáo PDF thật khi có backend hỗ trợ.
  Future<void> downloadEyeHealthReport() async {
    await Future.delayed(const Duration(seconds: 2));
  }

  /// Xóa dữ liệu local (SharedPreferences/cache) — không đụng tới tài khoản.
  Future<void> deleteAllLocalData() async {
    _isDeletingLocal = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _isDeletingLocal = false;
    notifyListeners();
  }

  /// Xóa tài khoản thật qua Firebase (AuthService.deleteAccount).
  Future<void> deleteAccount() async {
    _isDeletingAccount = true;
    notifyListeners();
    try {
      await AuthService.instance.deleteAccount();
    } finally {
      _isDeletingAccount = false;
      notifyListeners();
    }
  }

  // ---- Sign out ----
  bool _isSigningOut = false;
  bool get isSigningOut => _isSigningOut;

  /// Đăng xuất thật qua Firebase (AuthService.signOut).
  Future<void> signOut() async {
    _isSigningOut = true;
    notifyListeners();
    try {
      await AuthService.instance.signOut();
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }
}
