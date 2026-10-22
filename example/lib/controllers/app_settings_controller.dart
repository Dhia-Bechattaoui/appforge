import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

/// Global controller managing theme mode, active language, and application status.
class AppSettingsController extends AppController {
  /// Whether the app is currently displaying in dark mode.
  bool get isDarkMode => App.isDark;

  /// Toggles between light and dark themes using AppForge dynamic theming.
  void toggleTheme() {
    App.toggleTheme();
  }

  /// Sets an explicit theme mode (system, light, or dark).
  void setThemeMode(ThemeMode mode) {
    App.setThemeMode(mode);
  }

  /// Toggles between English and Arabic using AppForge localization.
  void toggleLanguage() {
    final nextLocale = App.isRtl
        ? const Locale('en', 'US')
        : const Locale('ar');
    App.setLocale(nextLocale);
  }

  /// Number of active controllers in the service locator.
  int get registeredControllerCount =>
      AppLocator.instance.activeControllers.length;

  /// Observable loading state for skeleton shimmer showcase.
  final isShimmerLoading = true.obs;

  /// Toggles the skeleton loading state between shimmer and actual data.
  void toggleShimmer() {
    isShimmerLoading.toggle();
  }

  /// Observable trigger for AppCache stats updates.
  final cacheUpdateTrigger = 0.obs;

  /// Signals that a cache operation occurred and UI should refresh stats.
  void notifyCacheChanged() {
    cacheUpdateTrigger.value++;
  }
}
