import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppTheme.gradientFor(Theme.of(context).colorScheme.primary),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text('🤖', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(strings.aiAssistant, style: Theme.of(context).textTheme.titleMedium),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          strings.online,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.success,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox.shrink(),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // CHAT DISABLED: NVIDIA NIM was only for testing.
          // Self-hosted 1-bit model planned — re-enable when ready.
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 48,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.chatDisabledTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.chatDisabledSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
