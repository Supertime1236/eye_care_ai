import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Toàn bộ logic đăng nhập/đăng ký/đăng xuất của app.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (displayName != null && displayName.isNotEmpty) {
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();
    }
    return _auth.currentUser;
  }

  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  Future<User?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  Future<void> deleteAccount() => _auth.currentUser!.delete();

  static String errorMessage(FirebaseAuthException e, bool vi) {
    final map = {
      'invalid-email': (vi ? 'Email không hợp lệ.' : 'Invalid email.'),
      'user-disabled': (vi ? 'Tài khoản đã bị vô hiệu hoá.' : 'This account is disabled.'),
      'user-not-found': (vi ? 'Không tìm thấy tài khoản.' : 'Account not found.'),
      'wrong-password': (vi ? 'Sai mật khẩu.' : 'Wrong password.'),
      'email-already-in-use': (vi ? 'Email đã được sử dụng.' : 'Email already in use.'),
      'weak-password': (vi ? 'Mật khẩu quá yếu (tối thiểu 6 ký tự).' : 'Password too weak (min 6 chars).'),
      'invalid-credential': (vi ? 'Email hoặc mật khẩu không đúng.' : 'Wrong email or password.'),
      'too-many-requests': (vi ? 'Thử lại sau ít phút.' : 'Try again in a few minutes.'),
    };
    return map[e.code] ?? (vi ? 'Đã xảy ra lỗi: ${e.message}' : 'Error: ${e.message}');
  }
}
