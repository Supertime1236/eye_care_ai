import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  // Trộn một chút màu accent vào nền/bề mặt trung tính, để đổi accent color
  // cũng cảm nhận được ở màu nền/card thay vì chỉ đổi màu nút bấm — giúp
  // giao diện "đầy màu sắc" hơn thực sự theo đúng lựa chọn của người dùng.
  // amount thấp (0.03–0.08) để không phá vỡ độ tương phản chữ/nền.
  static Color _tint(Color base, Color seed, double amount) {
    return Color.alphaBlend(seed.withValues(alpha: amount), base);
  }

  static ThemeData light({Color? accentSeed, TextTheme? fontTextTheme}) {
    final heading = fontTextTheme ?? GoogleFonts.beVietnamProTextTheme();
    final body = fontTextTheme ?? GoogleFonts.beVietnamProTextTheme();
    final seed = accentSeed ?? AppColors.primaryBlue;
    final background = _tint(AppColors.background, seed, 0.045);
    final surface = _tint(AppColors.surface, seed, 0.03);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        primary: seed,
        secondary: AppColors.primaryTeal,
        surface: surface,
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
        backgroundColor: background,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: heading.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }

  // Animation chuyển màn hình dùng chung: mượt hơn kiểu mặc định của
  // Android (vốn hơi "giật" khi push/pop) trên cả Android lẫn iOS, đồng thời
  // vẫn tôn trọng "reduce motion" của hệ điều hành người dùng.
  static const PageTransitionsTheme _pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    },
  );

  static ThemeData dark({Color? accentSeed, TextTheme? fontTextTheme}) {
    final heading = fontTextTheme ?? GoogleFonts.beVietnamProTextTheme();
    final body = fontTextTheme ?? GoogleFonts.beVietnamProTextTheme();
    final seed = accentSeed ?? AppColors.primaryBlue;
    final darkBackground = _tint(AppColors.darkBackground, seed, 0.07);
    final darkSurface = _tint(AppColors.darkSurface, seed, 0.05);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
        primary: seed,
        secondary: AppColors.primaryTeal,
        surface: darkSurface,
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
        backgroundColor: darkBackground,
        foregroundColor: Colors.white,
        titleTextStyle: heading.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.darkBorder),
      pageTransitionsTheme: _pageTransitionsTheme,
    );
  }
}

