import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class AppTheme {
  static VisualTheme get current => ThemeService.instance.currentTheme;

  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get surfaceLight => current.surfaceLight;
  static Color get surfaceCard => current.surfaceCard;

  static Color get primary => current.primary;
  static Color get secondary => current.secondary;
  static Color get accentGold => current.accent;
  static Color get darkGold => current.secondary;
  static Color get goldBorder => current.goldBorder;
  static Color get goldGlow => current.goldGlow;

  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get textMuted => current.textMuted;
  static Color get divider => current.goldBorder;

  static LinearGradient get primaryGradient => current.primaryGradient;
  static LinearGradient get goldGradient => current.primaryGradient;
  static LinearGradient get goldSurfaceGradient => current.surfaceGradient;
  static LinearGradient get darkGradient => current.darkGradient;

  static ThemeData get darkTheme => current.toThemeData();
}
