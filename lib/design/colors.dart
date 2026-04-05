import 'package:flutter/material.dart';

/// ratz.fyi design system color tokens.
/// Dark mode is default. Light mode overrides via JetlagTheme.
class JetlagColors {
  JetlagColors._();

  // === Dark Mode ===
  static const darkBg = Color(0xFF0C0E14);
  static const darkSurface = Color(0xFF151822);
  static const darkSurface2 = Color(0xFF1E2231);
  static const darkSurface3 = Color(0xFF272C3D);
  static const darkBorder = Color(0xFF2A2F42);
  static const darkBorderSubtle = Color(0xFF1E2231);
  static const darkText = Color(0xFFEEF0F6);
  static const darkText2 = Color(0xFF8B8FA3);
  static const darkText3 = Color(0xFF5C6070);

  // === Light Mode ===
  static const lightBg = Color(0xFFF0F2F7);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurface2 = Color(0xFFF5F6FA);
  static const lightSurface3 = Color(0xFFEBEDF3);
  static const lightBorder = Color(0xFFDFE1E9);
  static const lightBorderSubtle = Color(0xFFEBEDF3);
  static const lightText = Color(0xFF14171F);
  static const lightText2 = Color(0xFF4A4E5E);
  static const lightText3 = Color(0xFF8B8FA3);

  // === Accent Colors (shared) ===
  static const accent = Color(0xFF7B9AFF);
  static const accent2 = Color(0xFF5A7DE8);
  static const accentLight = Color(0xFF4A6ADF);
  static const accentLight2 = Color(0xFF3A54BF);

  // === Semantic Colors ===
  static const green = Color(0xFF5CEDA0);
  static const greenLight = Color(0xFF16A34A);
  static const red = Color(0xFFFF6B6B);
  static const redLight = Color(0xFFDC2626);
  static const orange = Color(0xFFFFB347);
  static const orangeLight = Color(0xFFD97706);
  static const purple = Color(0xFFB39DFF);
  static const purpleLight = Color(0xFF7C3AED);

  // === Glow Colors (dark mode) ===
  static const accentGlow = Color(0x267B9AFF); // 15% opacity
  static const accentGlow2 = Color(0x147B9AFF); // 8% opacity
  static const greenGlow = Color(0x1F5CEDA0); // 12%
  static const redGlow = Color(0x1FFF6B6B); // 12%
  static const orangeGlow = Color(0x1FFFB347); // 12%
  static const purpleGlow = Color(0x1FB39DFF); // 12%

  // === Glow Colors (light mode) ===
  static const accentGlowLight = Color(0x1A4A6ADF); // 10%
  static const greenGlowLight = Color(0x1416A34A); // 8%
  static const redGlowLight = Color(0x14DC2626); // 8%
  static const orangeGlowLight = Color(0x14D97706); // 8%
  static const purpleGlowLight = Color(0x147C3AED); // 8%

  // === Game Role Colors ===
  static const hider = green;
  static const seeker = red;
  static const spectator = darkText3;
  static const hiderLight = greenLight;
  static const seekerLight = redLight;

  // === Question Category Colors ===
  static const matching = accent;
  static const measuring = purple;
  static const radar = green;
  static const thermometer = orange;
  static const tentacles = Color(0xFF26C6DA); // teal
  static const photo = Color(0xFFEC407A); // pink
}

/// Radii matching the design system.
class JetlagRadii {
  JetlagRadii._();
  static const double sm = 10.0;
  static const double lg = 14.0;
  static const double xl = 18.0;
}
