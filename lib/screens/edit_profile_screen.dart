import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: context.read<ProfileProvider>().name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save(String successMsg, String failMsg) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final ok = await context.read<ProfileProvider>().saveProfile(name: _nameController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? successMsg : failMsg)));
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final strings = context.watch<LanguageProvider>().strings;

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
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                  backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                  child: profile.avatarUrl == null
                      ? Text(
                          profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, color: AppColors.primaryBlue),
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
                      Expanded(
                        child: Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      const Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
