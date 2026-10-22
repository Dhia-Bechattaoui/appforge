import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

import 'translations.dart';
import 'controllers/app_settings_controller.dart';
import 'controllers/state_lab_controller.dart';
import 'controllers/lifecycle_lab_controller.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize zero-dependency AppStorage engine (loads disk cache into 0ms synchronous RAM)
  await App.initStorage();

  // Load zero-dependency Environment Configuration from .env file
  await App.loadEnv(fileName: '.env', isOptional: true);

  // Register Tier-0 core controllers into AppForge service locator
  App.put(AppSettingsController(), permanent: true);
  App.put(StateLabController(), permanent: true);
  App.put(LifecycleLabController(), permanent: true);

  // Single zero-boilerplate root widget replacing nested MaterialApp boilerplate
  runApp(
    MasterApp(
      title: 'AppForge Showcase',
      home: const HomeScreen(),
      translations: DemoAppTranslations(),
      initialLocale: const Locale('ar'),
      fallbackLocale: const Locale('en', 'US'),
      persistLocale: true,
      persistTheme: true,
      harmonizeTheme: true,
      designSize: const Size(390, 844),
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF041C4E),
          primary: const Color(0xFF041C4E),
          secondary: const Color(0xFFC99A3D),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardColor: Colors.white,
      ),
      // darkTheme is intentionally omitted so AppThemeHarmonizer automatically
      // derives a matching, WCAG AA contrast-safe dark theme!
    ),
  );
}
