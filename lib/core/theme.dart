import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Semantic colors following Apple Human Interface Guidelines.
class AppColors {
  AppColors._();

  // Dark System Colors
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSecondaryBackground = Color(0xFF1C1C1E);
  static const Color darkTertiaryBackground = Color(0xFF2C2C2E);
  static const Color darkAccentBlue = Color(0xFF0A84FF);
  static const Color darkLabel = Color(0xFFFFFFFF);
  static const Color darkSecondaryLabel = Color(0xFF8E8E93);
  static const Color darkTertiaryLabel = Color(0xFF48484A);
  static const Color darkSeparator = Color(0xFF38383A);

  // Light System Colors
  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSecondaryBackground = Color(0xFFFFFFFF);
  static const Color lightTertiaryBackground = Color(0xFFE5E5EA);
  static const Color lightAccentBlue = Color(0xFF007AFF);
  static const Color lightLabel = Color(0xFF000000);
  static const Color lightSecondaryLabel = Color(0xFF8E8E93);
  static const Color lightTertiaryLabel = Color(0xFFC7C7CC);
  static const Color lightSeparator = Color(0xFFC6C6C8);

  // Status Colors
  static const Color systemGreen = Color(0xFF34C759);
  static const Color systemRed = Color(0xFFFF3B30);
  static const Color systemOrange = Color(0xFFFF9500);

  // Liquid Glass Specifics
  static const Color glassBorderLight = Color(0x33FFFFFF);
  static const Color glassBorderDark = Color(0x1AFFFFFF);
  static const Color glassBgLight = Color(0x99FFFFFF);
  static const Color glassBgDark = Color(0x661C1C1E);
}

/// Liquid Glass Effects styling options.
class GlassEffects {
  static const double blurSigmaX = 20.0;
  static const double blurSigmaY = 20.0;

  static BoxDecoration decoration(BuildContext context, {double borderRadius = 20.0}) {
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? AppColors.glassBgDark : AppColors.glassBgLight,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark ? const Color(0x40000000) : const Color(0x1F000000),
          blurRadius: 30.0,
          spreadRadius: -5.0,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

/// Spring animation parameters for premium haptic transitions.
class AppSprings {
  static const Curve interactiveSpring = Cubic(0.16, 1.0, 0.3, 1.0);
  static const Duration defaultDuration = Duration(milliseconds: 400);
}

/// SF Pro dynamic typography scale.
class AppTypography {
  static TextStyle sfPro({
    required double fontSize,
    FontWeight fontWeight = FontWeight.normal,
    Color? color,
    double? letterSpacing,
  }) {
    return TextStyle(
      fontFamily: 'SF Pro',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  static TextStyle title1(BuildContext context, {Color? color}) {
    return sfPro(
      fontSize: 28.0,
      fontWeight: FontWeight.bold,
      color: color,
      letterSpacing: 0.36,
    );
  }

  static TextStyle headline(BuildContext context, {Color? color}) {
    return sfPro(
      fontSize: 17.0,
      fontWeight: FontWeight.w600,
      color: color,
      letterSpacing: -0.41,
    );
  }

  static TextStyle body(BuildContext context, {Color? color}) {
    return sfPro(
      fontSize: 17.0,
      fontWeight: FontWeight.normal,
      color: color,
      letterSpacing: -0.41,
    );
  }

  static TextStyle footnote(BuildContext context, {Color? color}) {
    return sfPro(
      fontSize: 13.0,
      fontWeight: FontWeight.normal,
      color: color,
      letterSpacing: -0.08,
    );
  }
}
