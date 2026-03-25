import 'package:flutter/material.dart';

class AppColors {
  // Main Color Palette
  static const Color mist = Color(0xFFEEEDF2);
  static const Color silverShadow = Color(0xFFDDDCE5);
  static const Color dusk = Color(0xFF4E4C66);
  static const Color nightfall = Color(0xFF3E3D52);
  static const Color deepLavender = Color(0xFF413F55);
  static const Color obsidian = Color(0xFF262532);

  // Status Colors (from original app, or keeping variations)
  static const Color statusFound = Color(0xFF10B981); // Emerald Green
  static const Color statusLost = Color(0xFFEF4444); // Red
  static const Color statusPending = Color(0xFFD97706); // Amber 700
  static const Color statusOpen = Color(0xFF16A34A); // Green 600
  static const Color statusResolved = Color(0xFF2563EB); // Blue 600

  static const Color statusPendingSoft = Color(0xFFFFF3E0);
  static const Color statusOpenSoft = Color(0xFFE8F5E9);
  static const Color statusResolvedSoft = Color(0xFFE8EEFF);
  static const Color error = Color(0xFFEF4444);

  // General App Background
  static const Color background =
      mist; // Or whichever you prefer, using mist as light mode background

  // Admin Verification UI
  static const Color adminVerificationInk = Color(0xFF333345);
  static const Color adminVerificationMutedInk = Color(0xFF56556B);
  static const Color adminVerificationComparisonTitle = Color(0xFF3F3E52);
  static const Color adminVerificationSurfaceSoft = Color(0xFFF7F8FC);
  static const Color adminVerificationSurfacePanel = Color(0xFFF6F7FB);
  static const Color adminVerificationBorderSoft = Color(0xFFE9EAF0);
  static const Color adminVerificationPillSoft = Color(0xFFF3F4F8);
}
