import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // --- Light Mode ---
  static const Color primaryLight = Color(0xFF1A56DB);
  static const Color primaryPressedLight = Color(0xFF1347B5);
  static const Color primaryTintLight = Color(0xFFEFF6FF);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceAltLight = Color(0xFFF8FAFC);
  static const Color borderLight = Color(0xFFCBD5E1);
  static const Color dividerLight = Color(0xFFE2E8F0);
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textDisabledLight = Color(0xFF94A3B8);

  // --- Dark Mode ---
  static const Color primaryDark = Color(0xFF3B82F6);
  static const Color primaryPressedDark = Color(0xFF2563EB);
  static const Color primaryTintDark = Color(0x293B82F6);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceAltDark = Color(0xFF172033);
  static const Color borderDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF1E293B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textDisabledDark = Color(0xFF64748B);

  // --- Semantic / Status (same token names, mode-aware values handled in theme) ---

  // Hot tag
  static const Color tagHotBgLight = Color(0xFFFEE2E2);
  static const Color tagHotTextLight = Color(0xFF991B1B);
  static const Color tagHotBgDark = Color(0x29EF4444);
  static const Color tagHotTextDark = Color(0xFFF87171);

  // Warm tag
  static const Color tagWarmBgLight = Color(0xFFFEF3C7);
  static const Color tagWarmTextLight = Color(0xFF92400E);
  static const Color tagWarmBgDark = Color(0x29F59E0B);
  static const Color tagWarmTextDark = Color(0xFFFBBF24);

  // Cold tag
  static const Color tagColdBgLight = Color(0xFFDBEAFE);
  static const Color tagColdTextLight = Color(0xFF1D4ED8);
  static const Color tagColdBgDark = Color(0x2938BDF8);
  static const Color tagColdTextDark = Color(0xFF38BDF8);

  // Waste tag
  static const Color tagWasteBgLight = Color(0xFFF1F5F9);
  static const Color tagWasteTextLight = Color(0xFF64748B);
  static const Color tagWasteBgDark = Color(0xFF334155);
  static const Color tagWasteTextDark = Color(0xFF94A3B8);

  // Success (completed follow-up, Done badge)
  static const Color successBgLight = Color(0xFFDCFCE7);
  static const Color successTextLight = Color(0xFF057A55);
  static const Color successBgDark = Color(0x2322C55E);
  static const Color successTextDark = Color(0xFF4ADE80);

  // Danger (delete, logout, destructive actions)
  static const Color dangerBgLight = Color(0xFFFEE2E2);
  static const Color dangerTextLight = Color(0xFFEF4444);
  static const Color dangerBgDark = Color(0x24EF4444);
  static const Color dangerTextDark = Color(0xFFF87171);

  // Warning (duplicate lead, overdue badge)
  static const Color warningBgLight = Color(0xFFFEF3C7);
  static const Color warningTextLight = Color(0xFFF59E0B);
  static const Color warningBgDark = Color(0x24F59E0B);
  static const Color warningTextDark = Color(0xFFFBBF24);

  // AI badge
  static const Color aiBadgeBgLight = Color(0xFFEFF6FF);
  static const Color aiBadgeTextLight = Color(0xFF1A56DB);
  static const Color aiBadgeBgDark = Color(0x293B82F6);
  static const Color aiBadgeTextDark = Color(0xFF3B82F6);
}
