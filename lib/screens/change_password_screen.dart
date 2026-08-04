import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/settings_more_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final strings = context.read<LanguageProvider>().strings;
    if (_newController.text != _confirmController.text) {
      setState(() => _error = strings.passwordsDontMatch);
      return;
    }
    if (_newController.text.trim().isEmpty || _currentController.text.trim().isEmpty) {
      setState(() => _error = strings.requiredField);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await context.read<SettingsMoreProvider>().changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(strings.passwordUpdated)));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthService.errorMessage(e, strings.vi));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.changePasswordTitle),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SectionCard(
          child: Column(
            children: [
              TextField(
                controller: _currentController,
                obscureText: true,
                decoration: _decoration(context, strings.currentPassword),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _newController,
                obscureText: true,
                decoration: _decoration(context, strings.newPassword),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: _decoration(context, strings.confirmNewPassword),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(strings.updatePassword),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Trước đây fillColor cứng AppColors.background (màu sáng cố định) khiến ô
  // nhập luôn trắng dù app đang ở Dark Mode -> chữ tối màu trên nền tối gần
  // như vô hình. Đổi sang màu "surface" của Theme hiện tại, tự đổi theo
  // sáng/tối.
  InputDecoration _decoration(BuildContext context, String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );
}
