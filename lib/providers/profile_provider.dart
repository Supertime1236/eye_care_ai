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

  // Tài khoản Google đã được liên kết với user hiện tại hay chưa — dựa vào
  // providerData thực tế (không suy ra từ "email có rỗng hay không", vì user
  // đăng ký bằng email/password vẫn có email dù chưa liên kết Gmail).
  bool get isGoogleLinked =>
      FirebaseAuth.instance.currentUser?.providerData.any((p) => p.providerId == 'google.com') ??
      false;

  // Đã đăng nhập hay chưa, KHÔNG PHÂN BIỆT phương thức (email/password hay
  // Google) — dùng để quyết định hiện nút "Đăng xuất" hay "Đăng nhập bằng
  // Gmail" ở Edit Profile. Trước đây màn hình đó dùng nhầm isGoogleLinked,
  // nên người đăng nhập bằng email/password vẫn thấy nút "Sign in with
  // Gmail" dù đã đăng nhập.
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// Gọi lại mỗi khi AuthProvider đổi user (đăng nhập/đăng xuất/đổi tên).
  void syncFromUser(User? user) {
    try {
      if (user == null) {
        _name = '';
        _email = '';
        _avatarUrl = null;
        notifyListeners();
        return;
      }
      _name = user.displayName ?? user.email?.split('@').first ?? '';
      _email = user.email ?? '';
      _avatarUrl = user.photoURL;
      notifyListeners();
    } catch (e, st) {
      // QUAN TRỌNG: nếu hàm này throw, nó sẽ chặn luôn các listener khác của
      // AuthProvider (vd _AppGate) không được gọi tới, khiến app đứng yên ở
      // LoginScreen dù đã đăng nhập thành công. Bắt lỗi tại đây để cô lập.
      debugPrint('⚠️ ProfileProvider.syncFromUser lỗi: $e\n$st');
    }
  }

  /// Đồng bộ ngay lập tức từ FirebaseAuth.currentUser — dùng ngay sau một
  /// thao tác đăng nhập/liên kết thủ công (link Google...) để không phải chờ
  /// tới lần phát tiếp theo của authStateChanges stream, vốn có thể có độ
  /// trễ nhỏ khiến UI hiện sai trạng thái trong giây lát.
  void refresh() => syncFromUser(FirebaseAuth.instance.currentUser);

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
