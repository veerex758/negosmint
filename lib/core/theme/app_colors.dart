import 'package:flutter/material.dart';

/// NegosMint's vault-green visual system.
class AppColors {
  AppColors._();

  static const Color cobalt = Color(0xFF8EA873); // sage
  static const Color violet = Color(0xFF627B59); // deep sage
  static const Color background = Color(0xFF0E2218); // vault green
  static const Color surface = Color(0xFF152D21);
  static const Color surfaceElevated = Color(0xFF1D3929);
  static const Color highlight = Color(0xFFCBD196); // sage gold
  static const Color success = Color(0xFF72D39B);
  static const Color danger = Color(0xFFFF8291);
  static const Color warning = Color(0xFFF4C76B);
  static const Color textPrimary = Color(0xFFF5F7ED);
  static const Color textSecondary = Color(0xFFAEBBAA);
  static const Color glassBorder = Color(0x33CBD196);
  static const Color glassFill = Color(0x1A152D21);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [highlight, cobalt],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF142D20), background],
  );

  static RadialGradient glowGradient(Color color, {double opacity = 0.35}) =>
      RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]);
}
