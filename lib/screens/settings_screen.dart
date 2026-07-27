import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/permission_helper.dart';

import '../models/app_strings.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';
import 'edit_profile_screen.dart';

// SettingsScreen là màn hình cài đặt chính của ứng dụng.
// Mục tiêu của màn hình này là cho phép người dùng thay đổi:
// - màu nền (Dark Mode)
// - đơn vị đo lường (Metric / Imperial)
// - định dạng giờ (12h / 24h)
// - ngôn ngữ (Tiếng Việt / English)
//
// Cách hoạt động:
// - Lấy các provider theo trách nhiệm riêng biệt.
// - Dùng LanguageProvider để lấy text phù hợp với ngôn ngữ hiện tại.
// - Gọi các provider tương ứng để thay đổi cài đặt và update UI.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mỗi provider chỉ cung cấp dữ liệu và thao tác thuộc trách nhiệm riêng.
    final theme = context.watch<ThemeProvider>();
    final language = context.watch<LanguageProvider>();
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();
    final strings = language.strings;
    final isDark = theme.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.settings, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          SectionCard(
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
              borderRadius: BorderRadius.circular(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                    backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                    child: profile.avatarUrl == null
                        ? Text(
                            profile.name.isNotEmpty ? profile.name[0].toUpperCase() : '👤',
                            style: const TextStyle(fontSize: 20, color: AppColors.primaryBlue),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.name.isEmpty ? '—' : profile.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          profile.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.notifications, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          // Phần thông báo: bật/tắt các loại nhắc nhở khác nhau.
          // Mỗi dòng gọi _ToggleTile với dữ liệu và callback riêng.
          _ToggleTile(
            icon: '☕',
            title: strings.breakReminders,
            subtitle: strings.breakRemindersSubtitle,
            value: settings.notifyBreaks,
            onChanged: (v) => settings.setNotification('breaks', v),
          ),
          _ToggleTile(
            icon: '👁️',
            title: strings.eyeTestReminders,
            subtitle: strings.eyeTestRemindersSubtitle,
            value: settings.notifyTests,
            onChanged: (v) => settings.setNotification('tests', v),
          ),
          _ToggleTile(
            icon: '✅',
            title: strings.habitTracking,
            subtitle: strings.habitTrackingSubtitle,
            value: settings.notifyHabits,
            onChanged: (v) => settings.setNotification('habits', v),
          ),
          _ToggleTile(
            icon: '💡',
            title: strings.aiTips,
            subtitle: strings.aiTipsSubtitle,
            value: settings.notifyTips,
            onChanged: (v) => settings.setNotification('tips', v),
          ),
          const SizedBox(height: 20),
          // Phần tùy chọn chính: chế độ tối, đơn vị đo lường, định dạng giờ, ngôn ngữ.
          // Các lựa chọn này thay đổi bố cục hiển thị của ứng dụng.
          Text(strings.preferences, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _SwitchRow(
                  icon: isDark ? '🌙' : '☀️',
                  title: strings.darkMode,
                  value: theme.isDarkMode,
                  onChanged: theme.toggleDarkMode,
                ),
                const Divider(height: 1, indent: 56),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cột bên trái: lựa chọn đơn vị đo lường.
                            // Chọn Metric hoặc Imperial để thay đổi cách hiển thị đơn vị.
                            Text(strings.measurementUnits, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            _SelectableOption(
                              label: strings.metricMeters,
                              selected: settings.useMetric,
                              onTap: () => settings.toggleMetric(true),
                            ),
                            const SizedBox(height: 8),
                            _SelectableOption(
                              label: strings.imperialFeet,
                              selected: !settings.useMetric,
                              onTap: () => settings.toggleMetric(false),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Cột bên phải: lựa chọn định dạng ngày/giờ.
                            // Phần này thay đổi định dạng hiển thị giờ trong toàn bộ app.
                            Text(strings.dateTime, style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                            _SelectableOption(
                              label: strings.hour12,
                              selected: !settings.is24Hour,
                              onTap: () => settings.toggleTimeFormat(false),
                            ),
                            const SizedBox(height: 8),
                            _SelectableOption(
                              label: strings.hour24,
                              selected: settings.is24Hour,
                              onTap: () => settings.toggleTimeFormat(true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 56),
                _ListTileOption(
                  icon: '🌐',
                  title: strings.language,
                  subtitle: strings.languageSubtitle,
                  valueLabel: language.isVietnamese ? strings.vietnamese : strings.english,
                  onTap: () => _showLanguageDialog(context, language, strings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.more, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          SectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuItem(icon: '🔒', title: strings.privacySecurity),
                const Divider(height: 1, indent: 56),
                _MenuItem(icon: '📋', title: strings.termsOfService),
                const Divider(height: 1, indent: 56),
                _MenuItem(icon: '❓', title: strings.helpSupport),
                const Divider(height: 1, indent: 56),
                _MenuItem(
                  icon: '📊',
                  title: 'Quyền sử dụng dữ liệu',
                  onTap: () => _showPermissionSettings(context),
                ),
                const Divider(height: 1, indent: 56),
                _MenuItem(
                  icon: '🚪',
                  title: strings.signOut,
                  color: AppColors.error,
                  onTap: () => context.read<AuthProvider>().signOut(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              strings.version,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// Widget tái sử dụng cho từng dòng cài đặt bật/tắt.
// Widget này hiển thị icon, tiêu đề, mô tả và công tắc.
class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
              activeThumbColor: AppColors.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}

// Widget để hiển thị một tùy chọn dạng on/off trong phần cài đặt.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primaryBlue.withValues(alpha: 0.5),
            activeThumbColor: AppColors.primaryBlue,
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.color,
    this.onTap,
  });

  final String icon;
  final String title;
  final Color? color;
  final VoidCallback? onTap;
  
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color ?? AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectableOption extends StatelessWidget {
  const _SelectableOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryBlue.withValues(alpha: 0.12) : null,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppColors.primaryBlue : null,
                    ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: AppColors.primaryBlue,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _ListTileOption extends StatelessWidget {
  const _ListTileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueLabel,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String subtitle;
  final String valueLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              valueLabel,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showLanguageDialog(BuildContext context, LanguageProvider language, AppStrings strings) async {
  final selected = await showDialog<bool>(
    context: context,
    builder: (context) {
      return SimpleDialog(
        title: Text(strings.selectOption),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.english),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.vietnamese),
          ),
        ],
      );
    },
  );

  if (selected != null) {
    language.toggleVietnamese(selected);
  }
}

// THÊM HÀM NÀY VÀO CUỐI FILE
void _showPermissionSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (context) {
      return FutureBuilder<Map<String, bool>>(
        future: PermissionHelper.checkAllPermissions(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 300,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          Map<String, bool> permissions = snapshot.data!;

          return StatefulBuilder(
            builder: (context, setState) {
              return DraggableScrollableSheet(
                initialChildSize: 0.6,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                expand: false,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          'Quyền sử dụng dữ liệu',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),

                        const SizedBox(height: 24),

                        _PermissionTile(
                          icon: '📱',
                          title: 'Thời gian sử dụng ứng dụng',
                          description:
                              'Theo dõi thời gian bạn dùng từng ứng dụng',
                          isGranted: permissions["usage"] ?? false,
                          onTap: () async {
                            await PermissionHelper.requestUsagePermission();

                            permissions =
                                await PermissionHelper.checkAllPermissions();

                            setState(() {});
                          },
                        ),

                        const Divider(),

                        _PermissionTile(
                          icon: '📍',
                          title: 'Vị trí GPS',
                          description: 'Theo dõi thời gian ngoài trời',
                          isGranted: permissions["location"] ?? false,
                          onTap: () async {
                            await PermissionHelper.requestLocationPermission();

                            permissions =
                                await PermissionHelper.checkAllPermissions();

                            setState(() {});
                          },
                        ),

                        const Divider(),

                        _PermissionTile(
                          icon: '🏃',
                          title: 'Phát hiện hoạt động',
                          description: 'Theo dõi vận động',
                          isGranted: permissions["activity"] ?? false,
                          onTap: () async {
                            await PermissionHelper.requestActivityPermission();

                            permissions =
                                await PermissionHelper.checkAllPermissions();

                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

// THÊM WIDGET _PermissionTile
class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.onTap,
  });

  final String icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withValues(alpha: 0.12)
                  : Colors.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isGranted ? 'Đã cấp' : 'Chưa cấp',
                        style: TextStyle(
                          fontSize: 11,
                          color: isGranted ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Icon(
            isGranted ? Icons.check_circle : Icons.arrow_forward,
            color: isGranted ? Colors.green : Colors.grey[400],
            size: 20,
          ),
        ],
      ),
    );
  }
}