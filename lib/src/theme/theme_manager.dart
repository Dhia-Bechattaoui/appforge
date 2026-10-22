import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Central dynamic theming engine for AppForge.
///
/// Manages [ThemeMode] across the entire app with zero dependencies and
/// provides instant toggling and reactive notifications.
class AppThemeManager {
  AppThemeManager._();

  static final AppThemeManager instance = AppThemeManager._();

  final ValueNotifier<ThemeMode> _themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  /// Reactive notifier for the active [ThemeMode].
  ValueNotifier<ThemeMode> get themeModeNotifier => _themeModeNotifier;

  /// The currently active [ThemeMode] (`system`, `light`, or `dark`).
  ThemeMode get themeMode => _themeModeNotifier.value;

  /// Changes the theme mode immediately.
  ///
  /// Example:
  /// ```dart
  /// App.setThemeMode(ThemeMode.dark);
  /// ```
  void setThemeMode(ThemeMode mode) {
    if (_themeModeNotifier.value != mode) {
      _themeModeNotifier.value = mode;
    }
  }

  /// Toggles between light and dark themes.
  ///
  /// If the current mode is [ThemeMode.system], it resolves the current
  /// OS brightness and switches to the opposite explicit theme.
  ///
  /// Example:
  /// ```dart
  /// App.toggleTheme();
  /// ```
  void toggleTheme() {
    if (_themeModeNotifier.value == ThemeMode.dark) {
      setThemeMode(ThemeMode.light);
    } else if (_themeModeNotifier.value == ThemeMode.light) {
      setThemeMode(ThemeMode.dark);
    } else {
      // System mode: resolve against OS brightness and toggle to opposite
      final systemBrightness =
          SchedulerBinding.instance.platformDispatcher.platformBrightness;
      if (systemBrightness == Brightness.dark) {
        setThemeMode(ThemeMode.light);
      } else {
        setThemeMode(ThemeMode.dark);
      }
    }
  }

  /// Whether the app is currently in dark mode.
  ///
  /// Resolves [ThemeMode.system] against the platform brightness.
  bool get isDark {
    switch (_themeModeNotifier.value) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return SchedulerBinding
                .instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  /// Whether the app is currently in light mode.
  bool get isLight => !isDark;

  /// Resets theme settings back to [ThemeMode.system] (useful in tests).
  void reset() {
    _themeModeNotifier.value = ThemeMode.system;
  }
}
