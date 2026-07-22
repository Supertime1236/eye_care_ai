import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final heading = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryTeal,
        surface: AppColors.surface,
      ),
      textTheme: TextTheme(
        displayLarge: heading.displayLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: heading.displayMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: heading.displaySmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: heading.headlineLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: heading.headlineMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: heading.headlineSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: heading.titleLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: heading.titleMedium?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: heading.titleSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: body.bodyLarge?.copyWith(color: AppColors.textPrimary),
        bodyMedium: body.bodyMedium?.copyWith(color: AppColors.textSecondary),
        bodySmall: body.bodySmall?.copyWith(color: AppColors.textMuted),
        labelLarge: heading.labelLarge?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: heading.labelMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: heading.labelSmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
    );
  }

  static ThemeData dark() {
    final heading = GoogleFonts.plusJakartaSansTextTheme();
    final body = GoogleFonts.dmSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        brightness: Brightness.dark,
        primary: AppColors.primaryBlue,
        secondary: AppColors.primaryTeal,
        surface: AppColors.darkSurface,
      ),
      textTheme: TextTheme(
        displayLarge: heading.displayLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        displayMedium: heading.displayMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        displaySmall: heading.displaySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: heading.headlineLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        headlineMedium: heading.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: heading.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: heading.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: heading.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: heading.titleSmall?.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: body.bodyLarge?.copyWith(color: Colors.white),
        bodyMedium: body.bodyMedium?.copyWith(color: Colors.white70),
        bodySmall: body.bodySmall?.copyWith(color: Colors.white60),
        labelLarge: heading.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: heading.labelMedium?.copyWith(
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: heading.labelSmall?.copyWith(
          color: Colors.white60,
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.darkBackground,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.darkBorder),
    );
  }
}

