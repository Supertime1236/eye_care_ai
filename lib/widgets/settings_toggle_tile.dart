import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dòng có tiêu đề, mô tả bên dưới và công tắc bên phải — dùng cho mọi
/// mục "bật/tắt kèm mô tả" trong Settings > More.
class SettingsToggleTile extends StatelessWidget {
  const SettingsToggleTile({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          description,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.3),
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).colorScheme.primary,
    );
  }
}

/// Nhãn nhỏ dùng để nhóm các mục trong một thẻ mở rộng, ví dụ
/// "QUYỀN RIÊNG TƯ", "BẢO MẬT", "QUẢN LÝ DỮ LIỆU".
class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Dòng điều hướng đơn giản, ví dụ "Đổi mật khẩu" -> mũi tên.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.title,
    required this.onTap,
    this.trailingText,
    this.icon,
  });

  final String title;
  final VoidCallback? onTap;
  final String? trailingText;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: icon != null ? Icon(icon, size: 20, color: AppColors.textSecondary) : null,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText!, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
      onTap: onTap,
    );
  }
}
