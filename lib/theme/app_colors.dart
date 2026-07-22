import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primaryBlue = Color(0xFF3B82F6);
  static const primaryTeal = Color(0xFF14B8A6);
  static const background = Color(0xFFF8FAFC);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const homeAccent = Color(0xFF3B82F6);
  static const testAccent = Color(0xFF8B5CF6);
  static const habitsAccent = Color(0xFF14B8A6);
  static const statsAccent = Color(0xFFF97316);
  static const chatAccent = Color(0xFF6366F1);
  static const settingsAccent = Color(0xFF64748B);

  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryTeal],
  );

  static const gradientScore = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF0D9488)],
  );

  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder = Color(0xFF334155);
}
