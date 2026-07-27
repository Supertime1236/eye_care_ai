import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import 'faq_accordion.dart';
import 'feedback_form.dart';
import 'settings_toggle_tile.dart';

class HelpSupportSection extends StatelessWidget {
  const HelpSupportSection({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionLabel(strings.faqTitle),
        const FaqAccordion(),
        SettingsSectionLabel(strings.contactSupport),
        _ContactButton(
          icon: Icons.email_outlined,
          label: strings.emailSupport,
          onTap: () {
            // TODO: mở mailto: hoặc chat hỗ trợ trong app.
          },
        ),
        const SizedBox(height: 8),
        _ContactButton(
          icon: Icons.bug_report_outlined,
          label: strings.reportBug,
          onTap: () {
            // TODO: mở form báo lỗi.
          },
        ),
        const SizedBox(height: 8),
        _ContactButton(
          icon: Icons.lightbulb_outline_rounded,
          label: strings.requestFeature,
          onTap: () {
            // TODO: mở form đề xuất tính năng.
          },
        ),
        SettingsSectionLabel(strings.feedbackTitle),
        const FeedbackForm(),
        SettingsSectionLabel(strings.aboutTitle),
        const _AboutGrid(),
      ],
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14.5)),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutGrid extends StatelessWidget {
  const _AboutGrid();

  // TODO: lấy giá trị thật từ package_info_plus / backend khi có.
  static const _items = <MapEntry<String, String>>[
    MapEntry('App Version', '2.4.1'),
    MapEntry('Build Number', '241'),
    MapEntry('Developer', 'Eye Care AI Team'),
    MapEntry('Powered by', 'Flutter'),
    MapEntry('AI Model', 'On-device CV + Cloud LLM'),
    MapEntry('Firebase', 'Connected'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in _items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            constraints: const BoxConstraints(minWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.key,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
      ],
    );
  }
}
