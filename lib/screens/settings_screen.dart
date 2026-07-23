import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_strings.dart';
import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../widgets/shared_widgets.dart';

// SettingsScreen là màn hình cài đặt chính của ứng dụng.
// Mục tiêu của màn hình này là cho phép người dùng thay đổi:
// - màu nền (Dark Mode)
// - đơn vị đo lường (Metric / Imperial)
// - định dạng giờ (12h / 24h)
// - ngôn ngữ (Tiếng Việt / English)
//
// Cách hoạt động:
// - Lấy AppState từ Provider
// - Dùng state.strings để lấy text phù hợp với ngôn ngữ hiện tại
// - Gọi các hàm state.toggle... để thay đổi cài đặt và update UI
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy AppState hiện tại từ Provider.
    // state chứa dữ liệu và phương thức thay đổi cài đặt.
    final state = context.watch<AppState>();
    final strings = state.strings;
    final isDark = state.isDarkMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(strings.settings, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 16),
          SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                  child: const Text('👤', style: TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex Nguyen',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'alex.nguyen@email.com',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_outlined, color: AppColors.textMuted, size: 20),
              ],
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
            value: state.notifyBreaks,
            onChanged: (v) => state.setNotification('breaks', v),
          ),
          _ToggleTile(
            icon: '👁️',
            title: strings.eyeTestReminders,
            subtitle: strings.eyeTestRemindersSubtitle,
            value: state.notifyTests,
            onChanged: (v) => state.setNotification('tests', v),
          ),
          _ToggleTile(
            icon: '✅',
            title: strings.habitTracking,
            subtitle: strings.habitTrackingSubtitle,
            value: state.notifyHabits,
            onChanged: (v) => state.setNotification('habits', v),
          ),
          _ToggleTile(
            icon: '💡',
            title: strings.aiTips,
            subtitle: strings.aiTipsSubtitle,
            value: state.notifyTips,
            onChanged: (v) => state.setNotification('tips', v),
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
                  value: state.isDarkMode,
                  onChanged: state.toggleDarkMode,
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
                              selected: state.useMetric,
                              onTap: () => state.toggleMetric(true),
                            ),
                            const SizedBox(height: 8),
                            _SelectableOption(
                              label: strings.imperialFeet,
                              selected: !state.useMetric,
                              onTap: () => state.toggleMetric(false),
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
                              selected: !state.is24Hour,
                              onTap: () => state.toggleTimeFormat(false),
                            ),
                            const SizedBox(height: 8),
                            _SelectableOption(
                              label: strings.hour24,
                              selected: state.is24Hour,
                              onTap: () => state.toggleTimeFormat(true),
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
                  valueLabel: state.isVietnamese ? strings.vietnamese : strings.english,
                  onTap: () => _showLanguageDialog(context, state, strings),
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
                  icon: '🚪',
                  title: strings.signOut,
                  color: AppColors.error,
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
  });

  final String icon;
  final String title;
  final Color? color;

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

Future<void> _showLanguageDialog(BuildContext context, AppState state, AppStrings strings) async {
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
    state.toggleVietnamese(selected);
  }
}
