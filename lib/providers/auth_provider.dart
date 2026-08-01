import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';

/// Theo dõi trạng thái đăng nhập, dùng bởi _AppGate (main.dart) và Settings.
class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    _sub = AuthService.instance.authStateChanges.listen((user) {
      debugPrint('🔑 AuthProvider: stream fired, user=${user?.uid}, was=${_user?.uid}');
      _user = user;
      notifyListeners();
      debugPrint('🔑 AuthProvider: notifyListeners() called, isLoggedIn=$isLoggedIn');
    });
  }

  StreamSubscription<User?>? _sub;
  User? _user = AuthService.instance.currentUser;

  User? get user => _user;
  bool get isLoggedIn => _user != null;
  String get displayName => _user?.displayName ?? _user?.email?.split('@').first ?? '';

  Future<void> signOut() => AuthService.instance.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
