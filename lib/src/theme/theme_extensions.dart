import 'package:flutter/material.dart';
import 'theme_harmonizer.dart';

/// Context extensions providing ergonomic, boilerplate-free access to theme properties.
extension AppThemeContextExtension on BuildContext {
  /// The active [ThemeData] in the current context.
  ThemeData get theme => Theme.of(this);

  /// The active [ColorScheme] in the current context.
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// The active [TextTheme] in the current context.
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Whether the active theme is dark.
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Whether the active theme is light.
  bool get isLight => !isDark;

  /// Shortcut for [ColorScheme.primary].
  Color get primaryColor => Theme.of(this).colorScheme.primary;

  /// Shortcut for [ColorScheme.secondary].
  Color get secondaryColor => Theme.of(this).colorScheme.secondary;

  /// Shortcut for [ColorScheme.surface].
  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  /// Shortcut for [ThemeData.scaffoldBackgroundColor].
  Color get scaffoldBackgroundColor => Theme.of(this).scaffoldBackgroundColor;

  /// Shortcut for [ThemeData.cardColor].
  Color get cardColor => Theme.of(this).cardColor;

  /// Shortcut for [ThemeData.dividerColor].
  Color get dividerColor => Theme.of(this).dividerColor;

  /// Retrieves a registered [ThemeExtension] of type [T] from the current theme.
  ///
  /// Example:
  /// ```dart
  /// final brandPalette = context.tokens<BrandColors>();
  /// ```
  T? tokens<T>() => Theme.of(this).extension<T>();

  /// Returns a guaranteed high-contrast color (white or slate black) against [background].
  ///
  /// Useful for dynamic badge text, custom chips, and colored containers.
  Color contrastColor(Color background) {
    return background.computeLuminance() < 0.5
        ? Colors.white
        : const Color(0xFF0F172A);
  }
}

/// Zero-dependency Color extensions for WCAG 2.1 accessibility and contrast calculations.
extension AppColorContrastExtension on Color {
  /// Calculates the W3C relative contrast ratio against [other].
  ///
  /// Returns a value between 1.0 (identical) and 21.0 (black on white).
  double contrastRatio(Color other) =>
      AppThemeHarmonizer.contrastRatio(this, other);

  /// Whether this color satisfies WCAG AA minimum contrast ratio (4.5:1)
  /// against [background].
  bool hasAccessibleContrast(Color background, {double minRatio = 4.5}) =>
      contrastRatio(background) >= minRatio;

  /// Ensures this color satisfies [minRatio] contrast against [against].
  ///
  /// If contrast is insufficient, automatically shifts luminance while
  /// preserving hue and saturation.
  Color ensureContrast({required Color against, double minRatio = 4.5}) =>
      AppThemeHarmonizer.ensureContrast(
        foreground: this,
        background: against,
        minRatio: minRatio,
      );
}
