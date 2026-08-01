import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  // Đồng bộ text field với ProfileProvider MỖI LẦN build (không chỉ 1 lần ở
  // initState) — trước đây nếu Firebase chưa kịp trả dữ liệu lúc mở màn hình
  // này thì field mãi trống, không tự cập nhật khi dữ liệu về sau đó.
  String? _lastSyncedName;
  bool _linkingGoogle = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _syncNameField(String name) {
    if (_lastSyncedName == name) return;
    _lastSyncedName = name;
    _nameController.text = name;
  }

  Future<void> _save(String successMsg, String failMsg) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await context.read<ProfileProvider>().saveProfile(name: _nameController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? successMsg : failMsg)));
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _linkGoogleAccount(bool vi) async {
    setState(() => _linkingGoogle = true);
    try {
      await AuthService.instance.linkGoogleAccount();
      if (!mounted) return;
      // Không chờ authStateChanges stream (có độ trễ) -> đồng bộ ngay để nút
      // và ô email đổi trạng thái tức thì.
      context.read<ProfileProvider>().refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vi ? 'Đã liên kết Gmail!' : 'Gmail linked!')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AuthService.errorMessage(e, vi))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vi ? 'Lỗi liên kết Gmail: $e' : 'Gmail link error: $e')),
      );
    } finally {
      if (mounted) setState(() => _linkingGoogle = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final strings = context.watch<LanguageProvider>().strings;
    _syncNameField(profile.name);

    return Scaffold(
      appBar: AppBar(title: Text(strings.vi ? 'Chỉnh sửa hồ sơ' : 'Edit Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.primary),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                SectionCard(
                  child: TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: strings.fullName,
                      border: InputBorder.none,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? strings.requiredField : null,
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  child: Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          profile.email.isEmpty
                              ? (strings.vi ? 'Chưa liên kết email' : 'No email linked')
                              : profile.email,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Tooltip(
                        message: strings.vi
                            ? 'Email không thể sửa trực tiếp'
                            : "Email can't be edited directly",
                        child: const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: profile.isSaving
                        ? null
                        : () => _save(
                              strings.vi ? 'Đã lưu hồ sơ' : 'Profile updated',
                              strings.vi ? 'Không lưu được, thử lại.' : 'Could not save, try again.',
                            ),
                    child: profile.isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(strings.vi ? 'Lưu' : 'Save'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: profile.isLoggedIn
                      ? OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, size: 18, color: AppColors.error),
                          label: Text(
                            strings.vi ? 'Đăng xuất' : 'Sign out',
                            style: const TextStyle(color: AppColors.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: AppColors.error),
                          ),
                        )
                      : OutlinedButton.icon(
                          onPressed: _linkingGoogle ? null : () => _linkGoogleAccount(strings.vi),
                          icon: _linkingGoogle
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const GoogleGBadge(size: 18),
                          label: Text(strings.vi ? 'Đăng nhập bằng Gmail' : 'Sign in with Gmail'),
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
