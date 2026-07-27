import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Hồ sơ người dùng (tên/email/avatar), lấy từ Firebase Auth hiện tại.
/// Đổi tên ở đây sẽ tự đồng bộ ngược lại Firebase (updateDisplayName).
class ProfileProvider extends ChangeNotifier {
  String _name = '';
  String _email = '';
  String? _avatarUrl;
  bool _isSaving = false;

  String get name => _name;
  String get email => _email;
  String? get avatarUrl => _avatarUrl;
  bool get isSaving => _isSaving;

  /// Gọi lại mỗi khi AuthProvider đổi user (đăng nhập/đăng xuất/đổi tên).
  void syncFromUser(User? user) {
    if (user == null) return;
    _name = user.displayName ?? user.email?.split('@').first ?? '';
    _email = user.email ?? '';
    _avatarUrl = user.photoURL;
    notifyListeners();
  }

  Future<bool> saveProfile({required String name}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    _isSaving = true;
    notifyListeners();
    try {
      await user.updateDisplayName(name);
      await user.reload();
      _name = name;
      return true;
    } catch (_) {
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
