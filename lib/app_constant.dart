// lib/app_constant.dart

import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF00A884);
  static const Color darkGreen = Color(0xFF075E54);
  static const Color lightGreen = Color(0xFF25D366);
  static const Color accentGreen = Color(0xFF00D9A3);

  static const Color successColor = Color(0xFF00C853);
  static const Color errorColor = Color(0xFFE53935);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color infoColor = Color(0xFF2196F3);

  static const Color backgroundColor = Color(0xFFF0F2F5);
  static const Color cardBackground = Colors.white;
  static const Color surfaceColor = Color(0xFFF7F8FA);

  static const Color textPrimary = Color(0xFF111B21);
  static const Color textSecondary = Color(0xFF667781);
  static const Color textLight = Color(0xFF8696A0);

  static const Color borderColor = Color(0xFFE9EDEF);

  // ============ GRADIENTS ✨ ============
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075E54), Color(0xFF00A884), Color(0xFF00D9A3)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F5F1), Color(0xFFF0F8F5)],
  );

  static const LinearGradient chatBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0F2F5), Color(0xFFE8F5F1), Color(0xFFF0F2F5)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF075E54), Color(0xFF00A884)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00A884), Color(0xFF25D366)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF004D40), Color(0xFF075E54), Color(0xFF00A884)],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient outgoingBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00A884), Color(0xFF00C88E)],
  );
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );
  static const TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );
  static const TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
}

class AppDimensions {
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double borderRadius = 16.0;
}

class AppConstants {
  // ZEGOCLOUD Console se copy karo: https://console.zegocloud.com
  static const int zegoAppId = 2115226072; // 👈 apna AppID (integer) yahan
  static const String zegoAppSign =
      'e2d978f7b761bdf0e43010904b1c60a0be849dc9762e797fc7f9498a04a6cb45'; // 👈 apna AppSign yahan
}
