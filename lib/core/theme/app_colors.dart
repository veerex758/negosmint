import 'package:flutter/material.dart';

/// NegosMint — "Midnight Cobalt" identity.
/// Cobalt. Precision. Motion.
class AppColors {
  AppColors._();

  // Brand
  static const Color cobalt = Color(0xFF3157FF);
  static const Color violet = Color(0xFF7C3AED);

  // Background / surfaces
  static const Color background = Color(0xFF070A14);
  static const Color surface = Color(0xFF101525);
  static const Color surfaceElevated = Color(0xFF151B30);

  // Accents
  static const Color highlight = Color(0xFFAFC8FF);
  static const Color success = Color(0xFF36D6B4);
  static const Color danger = Color(0xFFFF6B7A);
  static const Color warning = Color(0xFFFFC66B);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFF);
  static const Color textSecondary = Color(0xFF8D96AA);

  // Borders / glass
  static const Color glassBorder = Color(0x33AFC8FF); // highlight @ 20%
  static const Color glassFill = Color(0x14101525); // subtle translucent

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cobalt, violet],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B0F1D), background],
  );

  static RadialGradient glowGradient(Color color, {double opacity = 0.35}) {
    return RadialGradient(
      colors: [color.withOpacity(opacity), color.withOpacity(0)],
    );
  }
}
