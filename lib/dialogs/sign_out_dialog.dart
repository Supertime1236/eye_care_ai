import 'package:flutter/material.dart';

import '../models/app_strings.dart';
import '../theme/app_colors.dart';

Future<bool?> showSignOutDialog(BuildContext context, AppStrings strings) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(strings.signOutConfirmTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(strings.signOutConfirmDesc),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(strings.signOut),
        ),
      ],
    ),
  );
}
