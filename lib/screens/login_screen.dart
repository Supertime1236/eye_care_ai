import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'main_shell.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // BUG ĐÃ SỬA: trước đây màn hình này chỉ đăng nhập xong rồi NGỒI CHỜ
  // _AppGate (main.dart) tự watch AuthProvider và rebuild sang MainShell.
  // Trên thực tế đã xác nhận qua debug log: AuthProvider.notifyListeners()
  // chạy đúng, dữ liệu user đúng, nhưng _AppGate không luôn luôn rebuild kịp
  // (khiến người dùng thấy đăng nhập xong màn hình vẫn đứng yên ở đây).
  // -> Giờ chuyển hướng THẲNG sang MainShell ngay khi đăng nhập thành công,
  // không phụ thuộc vào việc widget cha có tự rebuild hay không.
  void _goToMainShell() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  Future<void> _signIn(bool vi) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await AuthService.instance.signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _goToMainShell();
      return;
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e, vi));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle(bool vi) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user == null && mounted) {
        // Người dùng tự đóng hộp thoại chọn tài khoản Google -> không phải lỗi.
        setState(() => _isLoading = false);
        return;
      }
      _goToMainShell();
      return;
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e, vi));
    } catch (e) {
      // QUAN TRỌNG: GoogleSignIn ném PlatformException (không phải
      // FirebaseAuthException) khi cấu hình sai — vd thiếu SHA-1 trong
      // Firebase Console. Trước đây lỗi này bị "nuốt" âm thầm, màn hình chỉ
      // đứng im không phản hồi gì. Giờ hiện rõ ra để biết chính xác lỗi gì.
      setState(() => _error = vi
          ? 'Lỗi đăng nhập Google: $e\n(Thường do thiếu SHA-1 trong Firebase Console)'
          : 'Google sign-in error: $e\n(Usually a missing SHA-1 in Firebase Console)');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword(bool vi) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = context.read<LanguageProvider>().strings.enterEmailFirst);
      return;
    }
    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.read<LanguageProvider>().strings.resetEmailSent)),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = AuthService.errorMessage(e, vi));
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: AppColors.gradientPrimary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('👁️', style: TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    strings.welcomeBack,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: strings.email,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: strings.password,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? strings.requiredField : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => _forgotPassword(strings.vi),
                      child: Text(strings.forgotPassword),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 4),
                    Text(_error!, style: const TextStyle(color: AppColors.error), textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : () => _signIn(strings.vi),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strings.login),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(strings.orDivider),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _signInWithGoogle(strings.vi),
                    icon: const GoogleGBadge(size: 20),
                    label: Text(strings.continueWithGoogle),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            ),
                    child: Text(strings.noAccountYet),
                  ),
                  // Bỏ qua đăng nhập lần đầu: vào thẳng app ở chế độ khách,
                  // vẫn có thể đăng nhập sau này trong Settings/Edit profile.
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (_) => const MainShell()),
                            ),
                    child: Text(
                      strings.vi ? 'Bỏ qua, dùng thử trước' : 'Skip for now',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}