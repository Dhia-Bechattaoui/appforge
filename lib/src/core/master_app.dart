import 'package:flutter/material.dart';
import '../localization/gender.dart';
import '../localization/localizations_delegate.dart';
import '../localization/translations.dart';
import '../navigation/navigator.dart';
import '../navigation/overlays.dart';
import '../responsive/responsive_scaler.dart';
import '../storage/storage.dart';
import '../theme/theme_harmonizer.dart';
import '../theme/theme_manager.dart';
import 'app.dart';

/// The root application container for AppForge.
///
/// Unifies context-free navigation, reactive localization, dynamic theming,
/// and screen scaling into a single zero-boilerplate wrapper replacing [MaterialApp].
///
/// Example:
/// ```dart
/// void main() {
///   runApp(
///     MasterApp(
///       title: 'My App',
///       home: const HomeScreen(),
///       translations: MyTranslations(),
///       initialLocale: const Locale('ar'),
///       fallbackLocale: const Locale('en'),
///       userGender: AppGender.male,
///       theme: ThemeData.light(),
///       darkTheme: ThemeData.dark(),
///       designSize: const Size(390, 844),
///     ),
///   );
/// }
/// ```
class MasterApp extends StatefulWidget {
  /// Creates an AppForge [MasterApp] root container.
  const MasterApp({
    super.key,
    this.title = '',
    this.home,
    this.initialRoute,
    this.routes = const <String, WidgetBuilder>{},
    this.onGenerateRoute,
    this.onUnknownRoute,
    this.navigatorObservers = const <NavigatorObserver>[],
    this.translations,
    this.initialLocale,
    this.fallbackLocale,
    this.supportedLocales,
    this.userGender,
    this.theme,
    this.darkTheme,
    this.themeMode,
    this.harmonizeTheme = true,
    this.persistLocale = false,
    this.persistTheme = false,
    this.designSize = AppResponsive.defaultDesignSize,
    this.debugShowCheckedModeBanner = false,
    this.builder,
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  /// Application title displayed by the OS task switcher.
  final String title;

  /// The default root widget.
  final Widget? home;

  /// Optional initial named route ([String]) or initial page ([Widget]).
  final Object? initialRoute;

  /// Static named routes map.
  final Map<String, WidgetBuilder> routes;

  /// Route generator callback for named navigation.
  final RouteFactory? onGenerateRoute;

  /// Route generator callback for unrecognized routes.
  final RouteFactory? onUnknownRoute;

  /// Observers for the root [Navigator].
  final List<NavigatorObserver> navigatorObservers;

  /// Application dictionary for internationalization.
  final AppTranslations? translations;

  /// Initial startup locale.
  final Locale? initialLocale;

  /// Fallback locale if an active key is missing.
  final Locale? fallbackLocale;

  /// Explicit supported locales list. If omitted, inferred from [translations].
  final Iterable<Locale>? supportedLocales;

  /// Global default grammatical gender for gender-aware localization.
  final AppGender? userGender;

  /// Light theme data.
  final ThemeData? theme;

  /// Dark theme data.
  final ThemeData? darkTheme;

  /// Theme mode (system, light, or dark). Defaults to [App.themeMode].
  final ThemeMode? themeMode;

  /// Whether to enable theme harmonization and WCAG auto-contrast (default: true).
  ///
  /// When true:
  /// - If only [theme] is provided, an optimized dark theme is derived automatically.
  /// - If only [darkTheme] is provided, an optimized light theme is derived automatically.
  /// - If both [theme] and [darkTheme] are provided, they are preserved as-is with zero mutation.
  final bool harmonizeTheme;

  /// Whether to automatically persist and restore the user's selected language in [AppStorage].
  final bool persistLocale;

  /// Whether to automatically persist and restore the user's selected theme mode in [AppStorage].
  final bool persistTheme;

  /// Baseline design size for responsive scaling (default: 390x844).
  final Size designSize;

  /// Turns off the debug banner in development mode.
  final bool debugShowCheckedModeBanner;

  /// Optional builder to wrap the root navigator.
  final TransitionBuilder? builder;

  /// Custom root navigator key. Defaults to [App.navigatorKey].
  final GlobalKey<NavigatorState>? navigatorKey;

  /// Custom root scaffold messenger key. Defaults to [App.scaffoldMessengerKey].
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  State<MasterApp> createState() => _MasterAppState();
}

class _MasterAppState extends State<MasterApp> {
  VoidCallback? _localePersistenceListener;
  VoidCallback? _themePersistenceListener;
  late ThemeData _resolvedTheme;
  late ThemeData _resolvedDarkTheme;

  void _resolveThemes() {
    if (widget.harmonizeTheme) {
      if (widget.theme != null && widget.darkTheme == null) {
        _resolvedTheme =
            AppThemeHarmonizer.ensureInputDecoration(widget.theme!);
        _resolvedDarkTheme = AppThemeHarmonizer.deriveDark(widget.theme!);
      } else if (widget.theme == null && widget.darkTheme != null) {
        _resolvedTheme = AppThemeHarmonizer.deriveLight(widget.darkTheme!);
        _resolvedDarkTheme =
            AppThemeHarmonizer.ensureInputDecoration(widget.darkTheme!);
      } else {
        // Both provided or neither provided -> zero mutation
        _resolvedTheme = widget.theme ?? ThemeData.light();
        _resolvedDarkTheme = widget.darkTheme ?? ThemeData.dark();
      }
    } else {
      _resolvedTheme = widget.theme ?? ThemeData.light();
      _resolvedDarkTheme = widget.darkTheme ?? ThemeData.dark();
    }
  }

  @override
  void initState() {
    super.initState();

    // Memoize derived themes once
    _resolveThemes();

    // Initialize responsive design reference size
    AppResponsive.init(designSize: widget.designSize);

    // Initialize translation engine if provided
    if (widget.translations != null) {
      AppLocalization.instance.init(
        translations: widget.translations,
        initialLocale: widget.initialLocale,
        fallbackLocale: widget.fallbackLocale,
      );
    } else if (widget.initialLocale != null) {
      AppLocalization.instance.setLocale(widget.initialLocale!);
    }

    // Restore persisted locale if enabled
    if (widget.persistLocale) {
      final savedLocaleTag =
          AppStorage('default').read<String>('appforge_locale');
      if (savedLocaleTag != null && savedLocaleTag.isNotEmpty) {
        final parts = savedLocaleTag.split('_');
        final restoredLocale =
            parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
        AppLocalization.instance.setLocale(restoredLocale);
      }

      _localePersistenceListener = () {
        final current = AppLocalization.instance.locale;
        final tag = current.countryCode != null
            ? '${current.languageCode}_${current.countryCode}'
            : current.languageCode;
        final storage = AppStorage('default');
        storage.write('appforge_locale', tag);
        storage.saveSync();
      };
      AppLocalization.instance.localeNotifier
          .addListener(_localePersistenceListener!);
    }

    // Set initial grammatical gender if provided
    if (widget.userGender != null) {
      AppLocalization.instance.setUserGender(widget.userGender!);
    }

    // Set initial theme mode if explicitly provided
    if (widget.themeMode != null) {
      AppThemeManager.instance.setThemeMode(widget.themeMode!);
    }

    // Restore persisted theme mode if enabled
    if (widget.persistTheme) {
      final savedThemeName =
          AppStorage('default').read<String>('appforge_theme_mode');
      if (savedThemeName != null && savedThemeName.isNotEmpty) {
        final restoredMode = ThemeMode.values.firstWhere(
          (m) => m.name == savedThemeName,
          orElse: () => ThemeMode.system,
        );
        AppThemeManager.instance.setThemeMode(restoredMode);
      }

      _themePersistenceListener = () {
        final currentMode = AppThemeManager.instance.themeMode;
        final storage = AppStorage('default');
        storage.write('appforge_theme_mode', currentMode.name);
        storage.saveSync();
      };
      AppThemeManager.instance.themeModeNotifier
          .addListener(_themePersistenceListener!);
    }
  }

  @override
  void didUpdateWidget(MasterApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.designSize != oldWidget.designSize) {
      AppResponsive.init(designSize: widget.designSize);
    }
    if (widget.theme != oldWidget.theme ||
        widget.darkTheme != oldWidget.darkTheme ||
        widget.harmonizeTheme != oldWidget.harmonizeTheme) {
      _resolveThemes();
    }
    if (widget.themeMode != null && widget.themeMode != oldWidget.themeMode) {
      AppThemeManager.instance.setThemeMode(widget.themeMode!);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // Hot reload updates the AppTranslations subclass code (its `keys` getter
    // now returns the modified map), but the localization engine still holds a
    // stale snapshot taken at init-time. Re-snapshot and clear the static cache
    // so every `.tr` lookup reads the fresh dictionary immediately.
    if (widget.translations != null) {
      AppLocalization.instance.translations = widget.translations;
    }
  }

  @override
  void dispose() {
    if (_localePersistenceListener != null) {
      AppLocalization.instance.localeNotifier
          .removeListener(_localePersistenceListener!);
    }
    if (_themePersistenceListener != null) {
      AppThemeManager.instance.themeModeNotifier
          .removeListener(_themePersistenceListener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to both locale changes and theme mode switches
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocalization.instance.localeNotifier,
        AppThemeManager.instance.themeModeNotifier,
      ]),
      builder: (context, _) {
        final activeLocale = AppLocalization.instance.locale;
        final activeThemeMode = AppThemeManager.instance.themeMode;

        // Resolve supported locales
        final supported = widget.supportedLocales ??
            (widget.translations?.supportedLocales.isNotEmpty == true
                ? widget.translations!.supportedLocales
                : [activeLocale]);

        // Resolve initial route widget
        Widget? resolvedHome = widget.home;
        String? resolvedInitialRoute;

        if (widget.initialRoute is Widget) {
          resolvedHome = widget.initialRoute as Widget;
        } else if (widget.initialRoute is String) {
          resolvedInitialRoute = widget.initialRoute as String;
        }

        return MaterialApp(
          key: const ValueKey('AppForgeMasterApp'),
          title: widget.title,
          home: resolvedHome,
          initialRoute: resolvedInitialRoute,
          routes: widget.routes,
          onGenerateRoute: widget.onGenerateRoute,
          navigatorObservers: [
            AppNavigator.instance.observer,
            ...widget.navigatorObservers
                .where((obs) => obs != AppNavigator.instance.observer),
          ],
          navigatorKey:
              widget.navigatorKey ?? AppNavigator.instance.navigatorKey,
          scaffoldMessengerKey: widget.scaffoldMessengerKey ??
              AppOverlay.instance.scaffoldMessengerKey,
          locale: activeLocale,
          supportedLocales: supported,
          localizationsDelegates: AppLocalizationsDelegate.delegates,
          theme: _resolvedTheme,
          darkTheme: _resolvedDarkTheme,
          themeMode: activeThemeMode,
          debugShowCheckedModeBanner: widget.debugShowCheckedModeBanner,
          builder: (context, child) {
            // Synchronize responsive screen metrics on layout changes
            AppResponsive.updateFromContext(context);

            final content = Directionality(
              textDirection: AppLocalization.instance.textDirection,
              child: child ?? const SizedBox.shrink(),
            );

            if (widget.builder != null) {
              return widget.builder!(context, content);
            }
            return content;
          },
        );
      },
    );
  }
}
