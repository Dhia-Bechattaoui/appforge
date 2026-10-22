import 'package:flutter/material.dart';

/// Zero-dependency Adaptive Theme Harmonizer and WCAG 2.1 Auto-Contrast Engine.
///
/// Automatically derives matching high-contrast dark or light themes when
/// developers provide only one theme, guaranteeing that dark text never
/// collides with dark backgrounds and light text never collides with light
/// backgrounds.
///
/// When a developer explicitly provides **both** `theme` and `darkTheme`,
/// this engine performs **zero mutation**, respecting their explicit design.
class AppThemeHarmonizer {
  AppThemeHarmonizer._();

  /// Calculates the W3C WCAG 2.1 relative contrast ratio between two colors.
  ///
  /// Returns a value between 1.0 (identical) and 21.0 (pure black on pure white).
  ///
  /// WCAG Guidelines:
  /// - Normal text: Minimum 4.5:1 (AA level)
  /// - Large text & UI components: Minimum 3.0:1
  static double contrastRatio(Color c1, Color c2) {
    final l1 = c1.computeLuminance();
    final l2 = c2.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Ensures that [foreground] has a minimum contrast ratio of [minRatio]
  /// against [background] (default 4.5 for WCAG AA compliance).
  ///
  /// If the contrast is already sufficient, [foreground] is returned unchanged.
  /// Otherwise, an adjusted color with optimal luminance and preserved hue
  /// is returned.
  static Color ensureContrast({
    required Color foreground,
    required Color background,
    double minRatio = 4.5,
  }) {
    if (contrastRatio(foreground, background) >= minRatio) {
      return foreground;
    }

    final isDarkBg = background.computeLuminance() < 0.5;
    final hsl = HSLColor.fromColor(foreground);

    if (isDarkBg) {
      // Background is dark -> foreground needs to be lighter
      // Step lightness upward until minRatio is achieved or pure white is reached
      var candidate = hsl;
      while (candidate.lightness < 0.95) {
        candidate = candidate.withLightness(
          (candidate.lightness + 0.05).clamp(0.0, 1.0),
        );
        if (contrastRatio(candidate.toColor(), background) >= minRatio) {
          return candidate.toColor();
        }
      }
      return Colors.white;
    } else {
      // Background is light -> foreground needs to be darker
      // Step lightness downward until minRatio is achieved or pure black is reached
      var candidate = hsl;
      while (candidate.lightness > 0.05) {
        candidate = candidate.withLightness(
          (candidate.lightness - 0.05).clamp(0.0, 1.0),
        );
        if (contrastRatio(candidate.toColor(), background) >= minRatio) {
          return candidate.toColor();
        }
      }
      return const Color(0xFF0F172A); // High-contrast slate black
    }
  }

  /// Automatically derives a polished, WCAG-compliant Dark Theme from a [lightTheme].
  ///
  /// Preserves the developer's typography, button styles, shapes, and brand
  /// hue while automatically generating dark surfaces and high-contrast text.
  static ThemeData deriveDark(ThemeData lightTheme) {
    final lightScheme = lightTheme.colorScheme;
    final primary = lightScheme.primary;

    // If the light theme's primary color is very dark (e.g. Navy Blue #041C4E),
    // elevating it ensures it remains prominent against dark backgrounds.
    final elevatedPrimary = primary.computeLuminance() < 0.25
        ? _elevateLightness(primary, targetLightness: 0.65)
        : primary;

    // Generate balanced dark ColorScheme from seed
    final baseDarkScheme = ColorScheme.fromSeed(
      seedColor: elevatedPrimary,
      brightness: Brightness.dark,
    );

    const darkScaffoldBg = Color(0xFF0A0F1D);
    const darkSurface = Color(0xFF131B2E);
    const darkCard = Color(0xFF1E293B);

    final darkScheme = baseDarkScheme.copyWith(
      primary: elevatedPrimary,
      surface: darkSurface,
      onSurface: Colors.white,
      onPrimary: _onColor(elevatedPrimary),
    );

    // Adapt text theme: preserve fonts/weights but ensure light high-contrast colors
    final darkTextTheme = _deriveDarkTextTheme(
      lightTheme.textTheme,
      surfaceBg: darkScaffoldBg,
    );

    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: darkScheme,
      scaffoldBackgroundColor: darkScaffoldBg,
      cardColor: darkCard,
      canvasColor: darkSurface,
      textTheme: darkTextTheme,
      primaryTextTheme: darkTextTheme,
      appBarTheme: lightTheme.appBarTheme.copyWith(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
      ),
      cardTheme: lightTheme.cardTheme.copyWith(
        color: darkCard,
      ),
      bottomNavigationBarTheme: lightTheme.bottomNavigationBarTheme.copyWith(
        backgroundColor: darkSurface,
        selectedItemColor: elevatedPrimary,
        unselectedItemColor: const Color(0xFF94A3B8),
      ),
      chipTheme: lightTheme.chipTheme.copyWith(
        backgroundColor: darkCard,
        selectedColor: elevatedPrimary,
        secondarySelectedColor: elevatedPrimary,
        labelStyle: const TextStyle(color: Color(0xFFF1F5F9)),
        secondaryLabelStyle: TextStyle(color: _onColor(elevatedPrimary)),
        disabledColor: const Color(0xFF334155),
        side: const BorderSide(color: Color(0xFF334155), width: 0.8),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(elevatedPrimary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(elevatedPrimary),
          foregroundColor: WidgetStatePropertyAll(_onColor(elevatedPrimary)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(elevatedPrimary),
          foregroundColor: WidgetStatePropertyAll(_onColor(elevatedPrimary)),
        ),
      ),
      inputDecorationTheme: lightTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: darkSurface,
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF334155), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: elevatedPrimary, width: 1.5),
        ),
      ),
    );
  }

  /// Automatically derives a polished, WCAG-compliant Light Theme from a [darkTheme].
  ///
  /// Preserves the developer's typography, button styles, shapes, and brand
  /// hue while automatically generating light surfaces and crisp dark text.
  static ThemeData deriveLight(ThemeData darkTheme) {
    final darkScheme = darkTheme.colorScheme;
    final primary = darkScheme.primary;

    // If the dark theme's primary color is very light,
    // deepen it so it has crisp contrast against light backgrounds.
    final deepenedPrimary = primary.computeLuminance() > 0.65
        ? _deepenLightness(primary, targetLightness: 0.35)
        : primary;

    // Generate balanced light ColorScheme from seed
    final baseLightScheme = ColorScheme.fromSeed(
      seedColor: deepenedPrimary,
      brightness: Brightness.light,
    );

    const lightScaffoldBg = Color(0xFFF8FAFC);
    const lightSurface = Colors.white;
    const lightCard = Colors.white;

    final lightScheme = baseLightScheme.copyWith(
      primary: deepenedPrimary,
      surface: lightSurface,
      onSurface: const Color(0xFF0F172A),
      onPrimary: _onColor(deepenedPrimary),
    );

    // Adapt text theme: preserve fonts/weights but ensure dark high-contrast colors
    final lightTextTheme = _deriveLightTextTheme(
      darkTheme.textTheme,
      surfaceBg: lightScaffoldBg,
    );

    return darkTheme.copyWith(
      brightness: Brightness.light,
      colorScheme: lightScheme,
      scaffoldBackgroundColor: lightScaffoldBg,
      cardColor: lightCard,
      canvasColor: lightSurface,
      textTheme: lightTextTheme,
      primaryTextTheme: lightTextTheme,
      appBarTheme: darkTheme.appBarTheme.copyWith(
        backgroundColor: lightSurface,
        foregroundColor: const Color(0xFF0F172A),
      ),
      cardTheme: darkTheme.cardTheme.copyWith(
        color: lightCard,
      ),
      bottomNavigationBarTheme: darkTheme.bottomNavigationBarTheme.copyWith(
        backgroundColor: lightSurface,
        selectedItemColor: deepenedPrimary,
        unselectedItemColor: const Color(0xFF64748B),
      ),
      chipTheme: darkTheme.chipTheme.copyWith(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: deepenedPrimary,
        secondarySelectedColor: deepenedPrimary,
        labelStyle: const TextStyle(color: Color(0xFF0F172A)),
        secondaryLabelStyle: TextStyle(color: _onColor(deepenedPrimary)),
        disabledColor: const Color(0xFFE2E8F0),
        side: BorderSide(color: Colors.grey.shade300, width: 0.8),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(deepenedPrimary),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(deepenedPrimary),
          foregroundColor: WidgetStatePropertyAll(_onColor(deepenedPrimary)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(deepenedPrimary),
          foregroundColor: WidgetStatePropertyAll(_onColor(deepenedPrimary)),
        ),
      ),
      inputDecorationTheme: darkTheme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
        ),
        labelStyle: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: deepenedPrimary, width: 1.5),
        ),
      ),
    );
  }

  /// Ensures that [theme] has a clean, polished, contrast-safe [InputDecorationTheme]
  /// if not already explicitly defined by the developer.
  static ThemeData ensureInputDecoration(ThemeData theme) {
    if (theme.inputDecorationTheme.fillColor != null) return theme;
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: isDark ? const Color(0xFF131B2E) : const Color(0xFFF8FAFC),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 13,
        ),
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          fontSize: 13,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
    );
  }

  // --- Internal Color Helpers ---

  static Color _elevateLightness(Color color,
      {required double targetLightness}) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(targetLightness.clamp(0.0, 1.0)).toColor();
  }

  static Color _deepenLightness(Color color,
      {required double targetLightness}) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(targetLightness.clamp(0.0, 1.0)).toColor();
  }

  static Color _onColor(Color background) {
    return background.computeLuminance() < 0.5 ? Colors.white : Colors.black87;
  }

  static TextTheme _deriveDarkTextTheme(TextTheme source,
      {required Color surfaceBg}) {
    TextStyle adapt(TextStyle? style) {
      if (style == null) return const TextStyle(color: Colors.white);
      return style.copyWith(
        color: ensureContrast(
          foreground: style.color ?? Colors.white,
          background: surfaceBg,
        ),
      );
    }

    return source.copyWith(
      displayLarge: adapt(source.displayLarge),
      displayMedium: adapt(source.displayMedium),
      displaySmall: adapt(source.displaySmall),
      headlineLarge: adapt(source.headlineLarge),
      headlineMedium: adapt(source.headlineMedium),
      headlineSmall: adapt(source.headlineSmall),
      titleLarge: adapt(source.titleLarge),
      titleMedium: adapt(source.titleMedium),
      titleSmall: adapt(source.titleSmall),
      bodyLarge: adapt(source.bodyLarge),
      bodyMedium: adapt(source.bodyMedium),
      bodySmall: adapt(source.bodySmall),
      labelLarge: adapt(source.labelLarge),
      labelMedium: adapt(source.labelMedium),
      labelSmall: adapt(source.labelSmall),
    );
  }

  static TextTheme _deriveLightTextTheme(TextTheme source,
      {required Color surfaceBg}) {
    const defaultDark = Color(0xFF0F172A);

    TextStyle adapt(TextStyle? style) {
      if (style == null) return const TextStyle(color: defaultDark);
      return style.copyWith(
        color: ensureContrast(
          foreground: style.color ?? defaultDark,
          background: surfaceBg,
        ),
      );
    }

    return source.copyWith(
      displayLarge: adapt(source.displayLarge),
      displayMedium: adapt(source.displayMedium),
      displaySmall: adapt(source.displaySmall),
      headlineLarge: adapt(source.headlineLarge),
      headlineMedium: adapt(source.headlineMedium),
      headlineSmall: adapt(source.headlineSmall),
      titleLarge: adapt(source.titleLarge),
      titleMedium: adapt(source.titleMedium),
      titleSmall: adapt(source.titleSmall),
      bodyLarge: adapt(source.bodyLarge),
      bodyMedium: adapt(source.bodyMedium),
      bodySmall: adapt(source.bodySmall),
      labelLarge: adapt(source.labelLarge),
      labelMedium: adapt(source.labelMedium),
      labelSmall: adapt(source.labelSmall),
    );
  }
}
