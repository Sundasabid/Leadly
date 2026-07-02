import 'package:flutter/material.dart';
import 'app_colors.dart';

// Tag colors are not part of Flutter's default ColorScheme, so they live here
// as a ThemeExtension registered on both themes.
class AppTagColors extends ThemeExtension<AppTagColors> {
  final Color hotBg;
  final Color hotText;
  final Color warmBg;
  final Color warmText;
  final Color coldBg;
  final Color coldText;
  final Color wasteBg;
  final Color wasteText;
  final Color successBg;
  final Color successText;
  final Color dangerBg;
  final Color dangerText;
  final Color warningBg;
  final Color warningText;
  final Color aiBadgeBg;
  final Color aiBadgeText;

  const AppTagColors({
    required this.hotBg,
    required this.hotText,
    required this.warmBg,
    required this.warmText,
    required this.coldBg,
    required this.coldText,
    required this.wasteBg,
    required this.wasteText,
    required this.successBg,
    required this.successText,
    required this.dangerBg,
    required this.dangerText,
    required this.warningBg,
    required this.warningText,
    required this.aiBadgeBg,
    required this.aiBadgeText,
  });

  static const light = AppTagColors(
    hotBg: AppColors.tagHotBgLight,
    hotText: AppColors.tagHotTextLight,
    warmBg: AppColors.tagWarmBgLight,
    warmText: AppColors.tagWarmTextLight,
    coldBg: AppColors.tagColdBgLight,
    coldText: AppColors.tagColdTextLight,
    wasteBg: AppColors.tagWasteBgLight,
    wasteText: AppColors.tagWasteTextLight,
    successBg: AppColors.successBgLight,
    successText: AppColors.successTextLight,
    dangerBg: AppColors.dangerBgLight,
    dangerText: AppColors.dangerTextLight,
    warningBg: AppColors.warningBgLight,
    warningText: AppColors.warningTextLight,
    aiBadgeBg: AppColors.aiBadgeBgLight,
    aiBadgeText: AppColors.aiBadgeTextLight,
  );

  static const dark = AppTagColors(
    hotBg: AppColors.tagHotBgDark,
    hotText: AppColors.tagHotTextDark,
    warmBg: AppColors.tagWarmBgDark,
    warmText: AppColors.tagWarmTextDark,
    coldBg: AppColors.tagColdBgDark,
    coldText: AppColors.tagColdTextDark,
    wasteBg: AppColors.tagWasteBgDark,
    wasteText: AppColors.tagWasteTextDark,
    successBg: AppColors.successBgDark,
    successText: AppColors.successTextDark,
    dangerBg: AppColors.dangerBgDark,
    dangerText: AppColors.dangerTextDark,
    warningBg: AppColors.warningBgDark,
    warningText: AppColors.warningTextDark,
    aiBadgeBg: AppColors.aiBadgeBgDark,
    aiBadgeText: AppColors.aiBadgeTextDark,
  );

  @override
  AppTagColors copyWith({
    Color? hotBg, Color? hotText,
    Color? warmBg, Color? warmText,
    Color? coldBg, Color? coldText,
    Color? wasteBg, Color? wasteText,
    Color? successBg, Color? successText,
    Color? dangerBg, Color? dangerText,
    Color? warningBg, Color? warningText,
    Color? aiBadgeBg, Color? aiBadgeText,
  }) {
    return AppTagColors(
      hotBg: hotBg ?? this.hotBg,
      hotText: hotText ?? this.hotText,
      warmBg: warmBg ?? this.warmBg,
      warmText: warmText ?? this.warmText,
      coldBg: coldBg ?? this.coldBg,
      coldText: coldText ?? this.coldText,
      wasteBg: wasteBg ?? this.wasteBg,
      wasteText: wasteText ?? this.wasteText,
      successBg: successBg ?? this.successBg,
      successText: successText ?? this.successText,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerText: dangerText ?? this.dangerText,
      warningBg: warningBg ?? this.warningBg,
      warningText: warningText ?? this.warningText,
      aiBadgeBg: aiBadgeBg ?? this.aiBadgeBg,
      aiBadgeText: aiBadgeText ?? this.aiBadgeText,
    );
  }

  @override
  AppTagColors lerp(AppTagColors? other, double t) {
    if (other is! AppTagColors) return this;
    return AppTagColors(
      hotBg: Color.lerp(hotBg, other.hotBg, t)!,
      hotText: Color.lerp(hotText, other.hotText, t)!,
      warmBg: Color.lerp(warmBg, other.warmBg, t)!,
      warmText: Color.lerp(warmText, other.warmText, t)!,
      coldBg: Color.lerp(coldBg, other.coldBg, t)!,
      coldText: Color.lerp(coldText, other.coldText, t)!,
      wasteBg: Color.lerp(wasteBg, other.wasteBg, t)!,
      wasteText: Color.lerp(wasteText, other.wasteText, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      aiBadgeBg: Color.lerp(aiBadgeBg, other.aiBadgeBg, t)!,
      aiBadgeText: Color.lerp(aiBadgeText, other.aiBadgeText, t)!,
    );
  }
}
