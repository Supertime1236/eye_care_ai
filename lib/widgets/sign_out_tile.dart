import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dialogs/sign_out_dialog.dart';
import '../providers/language_provider.dart';
import '../providers/settings_more_provider.dart';
import '../screens/login_screen.dart';
import '../theme/app_colors.dart';
import 'shared_widgets.dart';

/// Không mở rộng — chạm vào sẽ hiện dialog xác nhận, sau đó trạng thái
/// loading, xóa phiên đăng nhập thật (Firebase) rồi quay về màn hình đăng nhập.
class SignOutTile extends StatelessWidget {
  const SignOutTile({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    final strings = context.read<LanguageProvider>().strings;
    final confirmed = await showSignOutDialog(context, strings);
    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(width: 44, height: 44, child: CircularProgressIndicator(strokeWidth: 3)),
      ),
    );

    await context.read<SettingsMoreProvider>().signOut();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // đóng loading overlay
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SectionCard(
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _handleSignOut(context),
            splashColor: AppColors.error.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    strings.signOut,
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.error, fontSize: 15),
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
