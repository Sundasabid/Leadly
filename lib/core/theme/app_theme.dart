import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'app_radius.dart';
import 'app_tag_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        primary: AppColors.primaryLight,
        primaryPressed: AppColors.primaryPressedLight,
        primaryTint: AppColors.primaryTintLight,
        background: AppColors.backgroundLight,
        surface: AppColors.surfaceLight,
        surfaceVariant: AppColors.surfaceAltLight,
        outline: AppColors.borderLight,
        textPrimary: AppColors.textPrimaryLight,
        textSecondary: AppColors.textSecondaryLight,
        textDisabled: AppColors.textDisabledLight,
        tagColors: AppTagColors.light,
      );

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        primary: AppColors.primaryDark,
        primaryPressed: AppColors.primaryPressedDark,
        primaryTint: AppColors.primaryTintDark,
        background: AppColors.backgroundDark,
        surface: AppColors.surfaceDark,
        surfaceVariant: AppColors.surfaceAltDark,
        outline: AppColors.borderDark,
        textPrimary: AppColors.textPrimaryDark,
        textSecondary: AppColors.textSecondaryDark,
        textDisabled: AppColors.textDisabledDark,
        tagColors: AppTagColors.dark,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color primary,
    required Color primaryPressed,
    required Color primaryTint,
    required Color background,
    required Color surface,
    required Color surfaceVariant,
    required Color outline,
    required Color textPrimary,
    required Color textSecondary,
    required Color textDisabled,
    required AppTagColors tagColors,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryTint,
      onPrimaryContainer: primary,
      secondary: textSecondary,
      onSecondary: Colors.white,
      secondaryContainer: surfaceVariant,
      onSecondaryContainer: textPrimary,
      error: AppColors.dangerTextLight,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      outline: outline,
      outlineVariant: outline.withValues(alpha: 0.5),
      scrim: Colors.black,
    );

    final interBase = GoogleFonts.inter();

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      fontFamily: interBase.fontFamily,
      extensions: [tagColors],

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // Bottom nav
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w400),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.dangerTextLight, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.dangerTextLight, width: 2),
        ),
        hintStyle: GoogleFonts.inter(fontSize: 15, color: textDisabled),
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
      ),

      // Elevated button (primary filled)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),

      // Outlined button (secondary)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          minimumSize: const Size(double.infinity, 52),
          side: BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Divider
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),

      // Text theme — headings: Poppins, body/labels: Inter
      textTheme: GoogleFonts.interTextTheme(TextTheme(
        bodyLarge:  TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: textPrimary),
        bodySmall:  TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textSecondary),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSecondary),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary),
      )).copyWith(
        displayLarge:  GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary),
        displayMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary),
        displaySmall:  GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        headlineLarge:  GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        headlineMedium: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: textPrimary),
        headlineSmall:  GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge:  GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        titleMedium: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
      ),
    );
  }
}
