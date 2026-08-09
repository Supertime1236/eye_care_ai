import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../providers/setup_provider.dart';
import '../screens/setup_wizard_screen.dart';
import '../theme/app_theme.dart';
import '../utils/app_icon.dart';

/// Banner nhắc "hoàn tất thiết lập" ở đầu Trang chủ — chỉ hiện khi CÒN quyền
/// nào đó chưa được cấp (kể cả sau khi đã bấm "Bắt đầu sử dụng" ở cuối
/// Setup Wizard mà bỏ qua bớt vài bước, hoặc người dùng tự tắt quyền trong
/// Cài đặt máy về sau) — biến mất hẳn ngay khi mọi quyền đã được cấp đủ.
/// Bấm vào sẽ mở lại đúng Setup Wizard để cấp nốt phần còn thiếu.
class SetupStatusBanner extends StatelessWidget {
  const SetupStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final setup = context.watch<SetupProvider>();
    if (setup.loading || setup.allGranted) return const SizedBox.shrink();

    final strings = context.watch<LanguageProvider>().strings;
    final primary = Theme.of(context).colorScheme.primary;
    final progress = setup.totalCount == 0 ? 0.0 : setup.grantedCount / setup.totalCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SetupWizardScreen()),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppTheme.gradientFor(primary),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const AppIcon('🔧', size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.setupBannerTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.setupBannerSubtitle(setup.grantedCount, setup.totalCount),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
