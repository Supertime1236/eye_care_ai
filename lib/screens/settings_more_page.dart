import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/language_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/expandable_card.dart';
import '../widgets/help_support_section.dart';
import '../widgets/privacy_security_section.dart';
import '../widgets/sign_out_tile.dart';
import '../widgets/terms_of_service_section.dart';

/// Section nào sẽ tự mở khi vào trang, dùng khi điều hướng từ một mục
/// cụ thể trong Settings chính (ví dụ chạm "Privacy & Security").
enum SettingsMoreSection { privacy, terms, help }

class SettingsMorePage extends StatefulWidget {
  const SettingsMorePage({super.key, this.initialSection});

  final SettingsMoreSection? initialSection;

  @override
  State<SettingsMorePage> createState() => _SettingsMorePageState();
}

class _SettingsMorePageState extends State<SettingsMorePage> {
  final _privacyKey = GlobalKey<ExpandableCardState>();
  final _termsKey = GlobalKey<ExpandableCardState>();
  final _helpKey = GlobalKey<ExpandableCardState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (widget.initialSection) {
        case SettingsMoreSection.privacy:
          _privacyKey.currentState?.expand();
          break;
        case SettingsMoreSection.terms:
          _termsKey.currentState?.expand();
          break;
        case SettingsMoreSection.help:
          _helpKey.currentState?.expand();
          break;
        case null:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<LanguageProvider>().strings;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(strings.settingsMoreTitle),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Column(
          children: [
            ExpandableCard(
              key: _privacyKey,
              icon: Icons.privacy_tip_outlined,
              title: strings.privacySecurity,
              iconColor: AppColors.primaryBlue,
              child: const PrivacySecuritySection(),
            ),
            ExpandableCard(
              key: _termsKey,
              icon: Icons.gavel_rounded,
              title: strings.termsOfService,
              iconColor: AppColors.primaryTeal,
              child: const TermsOfServiceSection(),
            ),
            ExpandableCard(
              key: _helpKey,
              icon: Icons.help_outline_rounded,
              title: strings.helpSupport,
              iconColor: AppColors.statsAccent,
              child: const HelpSupportSection(),
            ),
            const SizedBox(height: 12),
            const SignOutTile(),
          ],
        ),
      ),
    );
  }
}
