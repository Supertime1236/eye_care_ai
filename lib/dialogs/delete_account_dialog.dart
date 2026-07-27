import 'package:flutter/material.dart';

import '../models/app_strings.dart';
import '../theme/app_colors.dart';

/// Hiển thị dialog xác nhận có cảnh báo cho hành động phá hủy dữ liệu.
/// Trả về `true` nếu người dùng xác nhận, `false`/`null` nếu không.
Future<bool?> showDeleteAccountDialog(BuildContext context, AppStrings strings) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.warning_rounded, color: AppColors.error, size: 30),
      ),
      title: Text(
        strings.deleteAccountTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: Text(strings.deleteAccountDesc, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          child: Text(strings.delete),
        ),
      ],
    ),
  );
}
