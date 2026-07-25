import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/usage_service.dart';


class PermissionHelper {
  // Kiểm tra quyền PACKAGE_USAGE_STATS
  static Future<bool> checkUsagePermission() async {
    return await UsageService.hasPermission();
  }


  // Yêu cầu quyền PACKAGE_USAGE_STATS
  static Future<bool> requestUsagePermission() async {
    if (!Platform.isAndroid) return true;

    await UsageService.openPermissionSettings();

    // Đợi người dùng quay lại app
    await Future.delayed(const Duration(seconds: 1));

    return await UsageService.hasPermission();
  }

  // Mở Settings để cấp quyền thủ công
  static Future<void> openUsageAccessSettings() async {
  if (!Platform.isAndroid) return;

    await UsageService.openPermissionSettings();
  }

  // Kiểm tra quyền Location
  static Future<bool> checkLocationPermission() async {
    final status = await Permission.location.status;
    return status.isGranted;
  }

  // Yêu cầu quyền Location
  static Future<bool> requestLocationPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  // Kiểm tra quyền Activity Recognition
  static Future<bool> checkActivityPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.status;
      return status.isGranted;
    }
    return true;
  }

  // Yêu cầu quyền Activity Recognition
  static Future<bool> requestActivityPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    }
    return true;
  }

  // Kiểm tra tất cả quyền cần thiết
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'usage': await checkUsagePermission(),
      'location': await checkLocationPermission(),
      'activity': await checkActivityPermission(),
    };
  }

  // Hiển thị dialog hướng dẫn cấp quyền
  static Future<void> showPermissionDialog(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onGrant,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              onGrant();
            },
            child: const Text('Cấp quyền'),
          ),
        ],
      ),
    );
  }
}