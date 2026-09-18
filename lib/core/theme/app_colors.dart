import 'package:flutter/material.dart';

/// NegosMint — "Minted Copper" identity.
/// Minted deals. Living paper.
///
/// Field names (cobalt, violet, etc.) are kept from the previous
/// "Midnight Cobalt" palette on purpose — every screen references
/// AppColors.cobalt/.violet/.highlight, and renaming them would mean
/// touching every file in the app for no functional gain. Only the
/// actual color values changed here.
class AppColors {
  AppColors._();

  // Brand
  static const Color cobalt = Color(0xFFCD8862); // copper
  static const Color violet = Color(0xFF9A5636); // rose-bronze

  // Background / surfaces
  static const Color background = Color(0xFF070A14);
  static const Color surface = Color(0xFF101525);
  static const Color surfaceElevated = Color(0xFF151B30);

  // Accents
  static const Color highlight = Color(0xFFE8C9A8); // warm champagne
  static const Color success = Color(0xFF36D6B4);
  static const Color danger = Color(0xFFFF6B7A);
  static const Color warning = Color(0xFFFFC66B);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFF);
  static const Color textSecondary = Color(0xFF8D96AA);

  // Borders / glass
  static const Color glassBorder = Color(0x33E8C9A8); // highlight @ 20%
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
      colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
    );
  }
}
