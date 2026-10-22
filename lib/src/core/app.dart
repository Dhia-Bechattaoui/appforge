import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart' show ScaffoldMessengerState, ThemeMode;
import 'package:flutter/widgets.dart';
import '../cache/cache.dart';
import '../cleaner/audit_report.dart';
import '../cleaner/translation_auditor.dart';
import '../config/env.dart';
import '../localization/arabic_utils.dart';
import '../localization/gender.dart';
import '../localization/localizations_delegate.dart';
import '../localization/orthography.dart';
import '../localization/translations.dart';
import '../navigation/navigator.dart';
import '../navigation/overlays.dart';
import '../navigation/transitions.dart';
import '../responsive/responsive_scaler.dart';
import '../state/locator.dart';
import '../state/rx.dart';
import '../storage/storage.dart';
import '../theme/theme_manager.dart';
import '../utils/connectivity.dart';
import 'lifecycle.dart';

/// Central facade for AppForge framework utilities.
///
/// Provides context-free access to localization, state management,
/// dynamic theming, and navigation.
class App {
  App._();

  /// Gets the currently active [ui.Locale].
  static ui.Locale get locale => AppLocalization.instance.locale;

  /// Listenable for locale updates.
  static ValueNotifier<ui.Locale> get localeNotifier =>
      AppLocalization.instance.localeNotifier;

  /// The active user gender for gender-aware translations.
  static AppGender get userGender => AppLocalization.instance.userGender;

  /// Listenable for global active user gender changes.
  static ValueNotifier<AppGender> get genderNotifier =>
      AppLocalization.instance.genderNotifier;

  /// Sets the active user gender immediately without app restart.
  ///
  /// Example:
  /// ```dart
  /// App.setUserGender(AppGender.female);
  /// ```
  static void setUserGender(AppGender gender) {
    AppLocalization.instance.setUserGender(gender);
  }

  /// Whether the current active locale uses a Right-to-Left text direction.
  static bool get isRtl => AppLocalization.instance.isRtl;

  /// Gets the current [ui.TextDirection].
  static ui.TextDirection get textDirection =>
      AppLocalization.instance.textDirection;

  /// Universal zero-dependency localization delegates for [MaterialApp].
  ///
  /// Prevents "No MaterialLocalizations found" and "locale not supported"
  /// errors for any language (including Arabic) without external packages.
  static List<LocalizationsDelegate<dynamic>> get localizationsDelegates =>
      AppLocalizationsDelegate.delegates;

  /// Changes the application locale immediately at runtime across all screens.
  ///
  /// Example:
  /// ```dart
  /// App.setLocale(const Locale('ar', 'QA'));
  /// ```
  static void setLocale(ui.Locale newLocale) {
    AppLocalization.instance.setLocale(newLocale);
  }

  // --- Arabic Language & Custom Dictionaries ---

  /// Registers custom words, proper names, or domain terms to the Arabic autocorrect dictionary.
  ///
  /// Example:
  /// ```dart
  /// App.registerArabicWords({
  ///   'ضياء': 'ضِياء',
  ///   'حميدان': 'حُميدان',
  ///   'ستارتب': 'ستارت آب',
  /// });
  /// ```
  static void registerArabicWords(Map<String, String> words) {
    AppArabicOrthography.registerCustomWords(words);
  }

  /// Clears all custom user-registered autocorrect words.
  static void clearArabicWords() {
    AppArabicOrthography.clearCustomWords();
  }

  /// Registers custom male/female pairs for Arabic grammatical gender inflection.
  ///
  /// Example:
  /// ```dart
  /// App.registerArabicGenderPairs([
  ///   ['كابتن', 'كابتنة'],
  ///   ['طبيبنا', 'طبيبتنا'],
  ///   ['مبرمج عبقري', 'مبرمجة عبقرية'],
  /// ]);
  /// ```
  static void registerArabicGenderPairs(List<List<String>> pairs) {
    AppArabic.registerGenderPairs(pairs);
  }

  /// Clears all custom user-registered gender inflection pairs.
  static void clearArabicGenderPairs() {
    AppArabic.clearCustomGenderPairs();
  }

  /// Registers custom grammatical gender (male or female) for specific Arabic nouns.
  ///
  /// Example:
  /// ```dart
  /// App.registerArabicNounGenders({
  ///   'كوفي': AppGender.male,
  ///   'براند': AppGender.male,
  /// });
  /// ```
  static void registerArabicNounGenders(Map<String, AppGender> genders) {
    AppGender.registerCustomNounGenders(genders);
  }

  /// Clears all custom user-registered noun grammatical genders.
  static void clearArabicNounGenders() {
    AppGender.clearCustomNounGenders();
  }

  /// Audits translations for cross-locale consistency, missing keys, empty values,
  /// and unused dead keys.
  ///
  /// If [projectDir] is provided, statically scans `.dart` files across the project
  /// to flag dead (unused) keys and unregistered keys used in code.
  ///
  /// Example:
  /// ```dart
  /// final report = App.auditTranslations(translations: MyTranslations());
  /// print(report.summary);
  /// ```
  static AppAuditReport auditTranslations({
    AppTranslations? translations,
    Directory? projectDir,
  }) {
    final trans = translations ?? AppLocalization.instance.translations;
    if (trans == null) {
      throw StateError(
        'App.auditTranslations(): No AppTranslations provided and AppLocalization has not been initialized with translations.',
      );
    }

    if (projectDir != null) {
      return AppTranslationAuditor.scanProject(
        rootDir: projectDir,
        translations: trans,
        runtimeMissingKeys: AppLocalization.instance.missingKeys,
      );
    }

    return AppTranslationAuditor.auditDictionary(
      trans,
      runtimeMissingKeys: AppLocalization.instance.missingKeys,
    );
  }

  // --- State & Dependency Injection ---

  /// Registers an instance [dependency] in the service locator.
  ///
  /// If [dependency] is an [AppController], its [AppController.onInit] lifecycle
  /// hook runs immediately.
  static T put<T>(
    T dependency, {
    String? tag,
    bool permanent = false,
    bool stack = false,
  }) {
    return AppLocator.instance.put<T>(
      dependency,
      tag: tag,
      permanent: permanent,
      stack: stack,
    );
  }

  /// Registers a factory [builder] that instantiates [T] only upon first access via [find].
  static void lazyPut<T>(
    T Function() builder, {
    String? tag,
    bool permanent = false,
  }) {
    AppLocator.instance.lazyPut<T>(
      builder,
      tag: tag,
      permanent: permanent,
    );
  }

  /// Registers an asynchronous factory [builder] for non-blocking background hydration.
  static Future<T> putAsync<T>(
    Future<T> Function() builder, {
    String? tag,
    bool permanent = false,
  }) {
    return AppLocator.instance.putAsync<T>(
      builder,
      tag: tag,
      permanent: permanent,
    );
  }

  /// Retrieves a registered dependency of type [T].
  static T find<T>({String? tag}) {
    return AppLocator.instance.find<T>(tag: tag);
  }

  /// Removes and disposes a registered dependency of type [T].
  static bool delete<T>({String? tag, bool force = false, T? instance}) {
    return AppLocator.instance
        .delete<T>(tag: tag, force: force, instance: instance);
  }

  /// Checks whether a dependency of type [T] is registered.
  static bool isRegistered<T>({String? tag}) {
    return AppLocator.instance.isRegistered<T>(tag: tag);
  }

  /// Resets the service locator.
  static void resetLocator({bool clearPermanent = false}) {
    AppLocator.instance.reset(clearPermanent: clearPermanent);
  }

  // --- App & OS Lifecycle ---

  /// Gets the current operating system [AppLifecycleState] (resumed, paused, inactive, detached, hidden).
  static AppLifecycleState get lifecycleState =>
      AppLifecycleManager.instance.currentState;

  /// Reactive notifier for operating system lifecycle transitions.
  static ValueNotifier<AppLifecycleState> get lifecycleNotifier =>
      AppLifecycleManager.instance.stateNotifier;

  /// Whether the application is currently in the active foreground (`resumed`).
  static bool get isForeground => lifecycleState == AppLifecycleState.resumed;

  /// Whether the application is currently in the background (`paused`).
  static bool get isBackground => lifecycleState == AppLifecycleState.paused;

  /// Registers a global callback for OS lifecycle changes.
  ///
  /// Returns an [RxSubscription] for clean cancellation.
  static RxSubscription onLifecycleChange(
    void Function(AppLifecycleState state) callback,
  ) {
    return AppLifecycleManager.instance.addListener(callback);
  }

  // --- Context-Free Navigation & Routing ---

  /// Global key bound to the root [NavigatorState]. Pass this to your MaterialApp.
  static GlobalKey<NavigatorState> get navigatorKey =>
      AppNavigator.instance.navigatorKey;

  /// Global navigator observer for tracking active routes and argument synchronization.
  static NavigatorObserver get navigatorObserver =>
      AppNavigator.instance.observer;

  /// Global key bound to the root [ScaffoldMessengerState]. Pass this to your MaterialApp.
  static GlobalKey<ScaffoldMessengerState> get scaffoldMessengerKey =>
      AppOverlay.instance.scaffoldMessengerKey;

  /// Current [BuildContext] from the root navigator.
  static BuildContext? get context => AppNavigator.instance.currentContext;

  /// Arguments passed into the currently active route via [App.to], [App.off], or [App.offAll].
  static Object? get arguments => AppNavigator.instance.currentArguments;

  /// Whether the navigator can currently pop the top route.
  static bool get canPop => AppNavigator.instance.canPop;

  /// Navigates to [page] without requiring a [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.to(const ProfileScreen(), arguments: user);
  /// ```
  static Future<T?> to<T>(
    Widget page, {
    Object? arguments,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
  }) {
    return AppNavigator.instance.to<T>(
      page,
      arguments: arguments,
      transition: transition,
      duration: duration,
      routeName: routeName,
    );
  }

  /// Replaces the current route with [page] without requiring [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.off(const HomeScreen());
  /// ```
  static Future<T?> off<T, TO>(
    Widget page, {
    Object? arguments,
    TO? result,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
  }) {
    return AppNavigator.instance.off<T, TO>(
      page,
      arguments: arguments,
      result: result,
      transition: transition,
      duration: duration,
      routeName: routeName,
    );
  }

  /// Clears the entire navigation stack and sets [page] as root without [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.offAll(const LoginScreen());
  /// ```
  static Future<T?> offAll<T>(
    Widget page, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
  }) {
    return AppNavigator.instance.offAll<T>(
      page,
      arguments: arguments,
      predicate: predicate,
      transition: transition,
      duration: duration,
      routeName: routeName,
    );
  }

  /// Pops the topmost route off the navigation stack.
  ///
  /// Example:
  /// ```dart
  /// App.back(updatedData);
  /// ```
  static void back<T>([T? result]) {
    AppNavigator.instance.back<T>(result);
  }

  // --- Context-Free Overlays, Dialogs & Feedback ---

  /// Displays a modern, floating snackbar notification without requiring [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.snackbar('نجاح', 'تم حفظ الإعدادات بنجاح', type: AppSnackbarType.success);
  /// ```
  static void snackbar(
    String title,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? textColor,
  }) {
    AppOverlay.instance.showSnackbar(
      title,
      message,
      type: type,
      duration: duration,
      icon: icon,
      onTap: onTap,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
  }

  /// Displays a modal dialog without requiring [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.dialog(const LogoutDialog());
  /// ```
  static Future<T?> dialog<T>(
    Widget dialog, {
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
  }) {
    return AppOverlay.instance.showDialog<T>(
      dialog,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
    );
  }

  /// Displays a modal bottom sheet without requiring [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.bottomSheet(const LanguageSelectorSheet());
  /// ```
  static Future<T?> bottomSheet<T>(
    Widget bottomSheet, {
    bool isDismissible = true,
    Color? backgroundColor,
    double? elevation,
    bool enableDrag = true,
    bool isScrollControlled = false,
  }) {
    return AppOverlay.instance.showBottomSheet<T>(
      bottomSheet,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor,
      elevation: elevation,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
    );
  }

  /// Displays a global, non-dismissible loading overlay for async operations.
  ///
  /// Example:
  /// ```dart
  /// App.showLoading(message: 'جارٍ المزامنة...');
  /// await syncData();
  /// App.hideLoading();
  /// ```
  static void showLoading({
    String? message,
    Widget? customIndicator,
  }) {
    AppOverlay.instance.showLoading(
      message: message,
      customIndicator: customIndicator,
    );
  }

  /// Dismisses the active global loading overlay.
  static void hideLoading() {
    AppOverlay.instance.hideLoading();
  }

  /// Whether the global loading overlay is currently visible.
  static bool get isLoadingOpen => AppOverlay.instance.isLoadingOpen;

  // --- Dynamic Theming ---

  /// The currently active [ThemeMode] (system, light, or dark).
  static ThemeMode get themeMode => AppThemeManager.instance.themeMode;

  /// Reactive notifier for the active [ThemeMode].
  static ValueNotifier<ThemeMode> get themeModeNotifier =>
      AppThemeManager.instance.themeModeNotifier;

  /// Changes the application theme mode immediately across all screens.
  ///
  /// Example:
  /// ```dart
  /// App.setThemeMode(ThemeMode.dark);
  /// ```
  static void setThemeMode(ThemeMode mode) {
    AppThemeManager.instance.setThemeMode(mode);
  }

  /// Toggles between light and dark theme modes.
  ///
  /// Example:
  /// ```dart
  /// App.toggleTheme();
  /// ```
  static void toggleTheme() {
    AppThemeManager.instance.toggleTheme();
  }

  /// Whether the application is currently displaying in dark mode.
  static bool get isDark => AppThemeManager.instance.isDark;

  /// Whether the application is currently displaying in light mode.
  static bool get isLight => AppThemeManager.instance.isLight;

  // --- Screen Sizing & Responsive Utilities ---

  /// The active baseline reference design size.
  static Size get designSize => AppResponsive.designSize;

  /// The detected device screen size.
  static Size get screenSize => AppResponsive.screenSize;

  /// Total width of the current screen.
  static double get screenWidth => AppResponsive.screenWidth;

  /// Total height of the current screen.
  static double get screenHeight => AppResponsive.screenHeight;

  /// Whether the device is mobile (< 600 dp).
  static bool get isMobile => AppResponsive.isMobile;

  /// Whether the device is tablet (>= 600 dp and < 1024 dp).
  static bool get isTablet => AppResponsive.isTablet;

  /// Whether the device is desktop (>= 1024 dp).
  static bool get isDesktop => AppResponsive.isDesktop;

  /// Listenable that notifies whenever screen metrics (size, orientation, ratio) change.
  static ValueNotifier<Size> get responsiveMetricsNotifier =>
      AppResponsive.metricsNotifier;

  /// Configures responsive scaler design reference and metrics.
  static void responsiveInit({
    Size designSize = AppResponsive.defaultDesignSize,
    Size? screenSize,
    double textScaleFactor = 1.0,
    double devicePixelRatio = 1.0,
  }) {
    AppResponsive.init(
      designSize: designSize,
      screenSize: screenSize,
      textScaleFactor: textScaleFactor,
      devicePixelRatio: devicePixelRatio,
    );
  }

  // --- Network Connectivity & Internet Monitor ---

  /// Reactive observable tracking whether the device currently has real internet reachability.
  ///
  /// Can be consumed directly in UI with `Watch`:
  /// ```dart
  /// Watch((context) => App.isOnline.value ? const HomeScreen() : const OfflineBanner());
  /// ```
  static Rx<bool> get isOnline => AppConnectivity.instance.isOnline;

  /// Whether the device is currently confirmed offline.
  static bool get isOffline => AppConnectivity.instance.isOffline;

  /// Stream of connectivity state changes.
  static Stream<bool> get onConnectivityChanged =>
      AppConnectivity.instance.onConnectivityChanged;

  /// Performs an immediate, one-off reachability check.
  static Future<bool> checkConnectivity({
    List<String>? hosts,
    Duration timeout = const Duration(seconds: 3),
  }) =>
      AppConnectivity.instance.checkConnection(hosts: hosts, timeout: timeout);

  /// Starts background periodic connectivity monitoring.
  static void startConnectivityMonitor({
    Duration interval = const Duration(seconds: 5),
    List<String>? hosts,
    Duration timeout = const Duration(seconds: 3),
  }) =>
      AppConnectivity.instance.startMonitoring(
        interval: interval,
        hosts: hosts,
        timeout: timeout,
      );

  /// Stops background connectivity monitoring.
  static void stopConnectivityMonitor() =>
      AppConnectivity.instance.stopMonitoring();

  // --- Persistent Storage Engine ---

  /// The default [AppStorage] instance (`'default'`).
  static AppStorage get storage => AppStorage('default');

  /// Access a named storage container partition (e.g. `App.storageBox('auth')`).
  static AppStorage storageBox([String container = 'default']) =>
      AppStorage(container);

  /// Initializes the storage engine on disk.
  ///
  /// Can be called in `main()` before `runApp()`:
  /// ```dart
  /// await App.initStorage();
  /// ```
  static Future<AppStorage> initStorage({
    String container = 'default',
    String? path,
  }) =>
      AppStorage.init(container: container, path: path);

  /// Synchronously reads a value from the default storage container RAM cache.
  static T? storageRead<T>(String key, {T? defaultValue}) =>
      AppStorage('default').read<T>(key, defaultValue: defaultValue);

  /// Writes a value to the default storage container.
  static void storageWrite(String key, dynamic value) =>
      AppStorage('default').write(key, value);

  /// Removes a key from the default storage container.
  static void storageRemove(String key) => AppStorage('default').remove(key);

  /// Clears all entries from the default storage container.
  static void storageClear() => AppStorage('default').clear();

  /// Checks if a key exists in the default storage container.
  static bool storageHas(String key) => AppStorage('default').has(key);

  // --- Environment Configuration (AppEnv) ---

  /// Loads and parses an environment file into memory.
  static Future<void> loadEnv({
    String fileName = '.env',
    AssetBundle? bundle,
    bool isOptional = false,
  }) =>
      AppEnv.load(
        fileName: fileName,
        bundle: bundle,
        isOptional: isOptional,
      );

  /// Retrieves an environment variable string, returning [defaultValue] if missing.
  static String env(String key, {String defaultValue = ''}) =>
      AppEnv.get(key, defaultValue: defaultValue);

  /// Retrieves an environment variable string, returning `null` if missing.
  static String? envOrNull(String key) => AppEnv.getOrNull(key);

  /// Retrieves an integer environment variable.
  static int envInt(String key, {int defaultValue = 0}) =>
      AppEnv.getInt(key, defaultValue: defaultValue);

  /// Retrieves a double-precision floating point environment variable.
  static double envDouble(String key, {double defaultValue = 0.0}) =>
      AppEnv.getDouble(key, defaultValue: defaultValue);

  /// Retrieves a boolean environment variable (accepts true/1/yes/on/enabled).
  static bool envBool(String key, {bool defaultValue = false}) =>
      AppEnv.getBool(key, defaultValue: defaultValue);

  /// Returns whether [key] exists in the loaded environment.
  static bool hasEnv(String key) => AppEnv.contains(key);

  /// Unmodifiable map of all loaded environment variables.
  static Map<String, String> get envMap => AppEnv.map;

  /// Loads environment variables directly from an in-memory [map].
  static void loadEnvFromMap(
    Map<String, String> map, {
    bool overwrite = true,
  }) =>
      AppEnv.loadFromMap(map, overwrite: overwrite);

  /// Unmodifiable sanitized map where sensitive keys are masked.
  static Map<String, String> get envMaskedMap => AppEnv.maskedMap();

  // --- In-Memory Cache Engine (AppCache) ---

  /// The default in-memory cache bucket.
  static AppCacheBucket get cache => AppCache.defaultBucket;

  /// Retrieves or initializes a named cache bucket with custom capacity and eviction.
  static AppCacheBucket cacheBucket(
    String name, {
    int maxEntries = 100,
    Duration? defaultTtl,
    CacheEvictionPolicy evictionPolicy = CacheEvictionPolicy.lru,
  }) =>
      AppCache.bucket(
        name,
        maxEntries: maxEntries,
        defaultTtl: defaultTtl,
        evictionPolicy: evictionPolicy,
      );
}
