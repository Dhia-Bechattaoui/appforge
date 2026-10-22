import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'bidi_utils.dart';
import 'common_translations.dart';
import 'gender.dart';
import 'orthography.dart';
import 'plurals.dart';

/// Base contract for app translations dictionary.
///
/// Example:
/// ```dart
/// class MyTranslations extends AppTranslations {
///   @override
///   Map<String, Map<String, String>> get keys => {
///     'en_US': {'hello': 'Hello', 'welcome': 'Welcome, @name!'},
///     'ar_QA': {
///       'hello': 'مرحباً',
///       'welcome_male': 'أهلاً بكَ يا @name!',
///       'welcome_female': 'أهلاً بكِ يا @name!',
///       'welcome': 'أهلاً بك يا @name!',
///     },
///   };
/// }
/// ```
abstract class AppTranslations {
  const AppTranslations();

  /// Map of locale keys to key-value translation pairs.
  Map<String, Map<String, String>> get keys;

  /// List of supported locales derived from dictionary keys.
  List<ui.Locale> get supportedLocales {
    return keys.keys.map((code) {
      final parts = code.split('_');
      if (parts.length > 1) {
        return ui.Locale(parts[0], parts[1]);
      }
      return ui.Locale(parts[0]);
    }).toList();
  }

  /// Creates an in-memory [AppTranslations] instance from a Map.
  factory AppTranslations.fromMap(Map<String, Map<String, String>> map) =>
      _MapAppTranslations(map);
}

class _MapAppTranslations extends AppTranslations {
  const _MapAppTranslations(this._keys);

  final Map<String, Map<String, String>> _keys;

  @override
  Map<String, Map<String, String>> get keys => _keys;
}

/// Central localization manager for AppForge.
///
/// Manages active locale, active user gender, translations dictionary,
/// fallback rules, BiDi parameter interpolation, and instant runtime switching.
class AppLocalization {
  AppLocalization._();

  static final AppLocalization instance = AppLocalization._();

  static final RegExp _phoneNumberRegex = RegExp(r'^\+?[0-9\s\-()]{6,}$');
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Determines whether [key] is a literal UI token (such as a hashtag, handle,
  /// URL, phone number, or email address) rather than a translatable dictionary key.
  /// Literal tokens bypass missing key tracking when invoked via `.tr`.
  static bool isLiteralToken(String key) {
    if (key.isEmpty) return true;
    final trimmed = key.trim();
    if (trimmed.startsWith('#') || trimmed.startsWith('@')) {
      return true;
    }
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('mailto:') ||
        trimmed.startsWith('tel:')) {
      return true;
    }
    if (trimmed.startsWith('+') || _phoneNumberRegex.hasMatch(trimmed)) {
      return true;
    }
    if (_emailRegex.hasMatch(trimmed)) {
      return true;
    }
    return false;
  }

  AppTranslations? _translations;
  Map<String, Map<String, String>> _snapshottedKeys = const {};
  final Map<String, String> _staticCache = <String, String>{};

  ui.Locale _locale = const ui.Locale('en', 'US');
  ui.Locale _fallbackLocale = const ui.Locale('en', 'US');
  AppGender _userGender = AppGender.other;

  String _localeExactKey = 'en_US';
  String _localeLangCode = 'en';
  String _fallbackExactKey = 'en_US';
  String _fallbackLangCode = 'en';

  void _updateLocaleKeys() {
    _localeExactKey = '${_locale.languageCode}_${_locale.countryCode ?? ''}';
    _localeLangCode = _locale.languageCode;
    _fallbackExactKey =
        '${_fallbackLocale.languageCode}_${_fallbackLocale.countryCode ?? ''}';
    _fallbackLangCode = _fallbackLocale.languageCode;
    _staticCache.clear();
  }

  /// Listenable for locale changes. Widgets can subscribe to this
  /// or rely on MasterApp which rebuilds automatically on change.
  final ValueNotifier<ui.Locale> localeNotifier =
      ValueNotifier<ui.Locale>(const ui.Locale('en', 'US'));

  /// Listenable for global active user gender changes.
  final ValueNotifier<AppGender> genderNotifier =
      ValueNotifier<AppGender>(AppGender.other);

  /// The currently active [ui.Locale].
  ui.Locale get locale => _locale;

  /// The fallback [ui.Locale] used when a key is missing in the active locale.
  ui.Locale get fallbackLocale => _fallbackLocale;

  /// The active [AppTranslations] dictionary registry, if initialized.
  AppTranslations? get translations => _translations;

  /// Sets or updates the active translations dictionary, snapshotting keys and invalidating cache.
  set translations(AppTranslations? value) {
    _translations = value;
    _snapshottedKeys = value?.keys ?? const {};
    _staticCache.clear();
  }

  /// Sets or updates the translations dictionary, snapshotting keys and invalidating cache.
  void setTranslations(AppTranslations translations) {
    this.translations = translations;
  }

  /// Invalidates the internal translations key snapshot and static lookup cache.
  void invalidateCache() {
    _snapshottedKeys = _translations?.keys ?? const {};
    _staticCache.clear();
  }

  /// The global active user gender.
  AppGender get userGender => _userGender;

  /// Returns the current text direction ([ui.TextDirection.rtl] or [ui.TextDirection.ltr]).
  ui.TextDirection get textDirection =>
      AppBidi.textDirectionForLocale(_locale.languageCode);

  /// Whether the active locale is Right-to-Left.
  bool get isRtl => textDirection == ui.TextDirection.rtl;

  /// Optional listener invoked whenever a requested translation key cannot be resolved.
  void Function(String key, ui.Locale locale)? onMissingKey;

  /// All unique missing translation keys requested during runtime execution.
  final Set<String> _missingKeys = <String>{};

  /// Unmodifiable set of all missing keys requested at runtime.
  Set<String> get missingKeys => Set.unmodifiable(_missingKeys);

  /// Clears the accumulated runtime missing keys.
  void clearMissingKeys() => _missingKeys.clear();

  /// Initializes the localization system with translations and initial locale.
  void init({
    AppTranslations? translations,
    ui.Locale? initialLocale,
    ui.Locale? fallbackLocale,
    AppGender? userGender,
  }) {
    if (translations != null) {
      _translations = translations;
      _snapshottedKeys = translations.keys;
    }
    if (fallbackLocale != null) {
      _fallbackLocale = fallbackLocale;
    }
    if (initialLocale != null) {
      _locale = initialLocale;
      localeNotifier.value = initialLocale;
    }
    if (userGender != null) {
      _userGender = userGender;
      genderNotifier.value = userGender;
    }
    _updateLocaleKeys();
  }

  /// Changes the application language at runtime immediately without app restart.
  void setLocale(ui.Locale newLocale) {
    if (_locale == newLocale) return;
    _locale = newLocale;
    _updateLocaleKeys();
    localeNotifier.value = newLocale;
  }

  /// Updates the global active user gender immediately without app restart.
  void setUserGender(AppGender gender) {
    if (_userGender == gender) return;
    _userGender = gender;
    _staticCache.clear();
    genderNotifier.value = gender;
  }

  /// Translates a key with optional parameter interpolation, BiDi protection,
  /// and grammatical gender selection.
  String translate(
    String key, {
    Map<String, String>? params,
    bool sanitizeBiDi = true,
    AppGender? gender,
  }) {
    final targetGender = gender ?? _userGender;
    final isStatic =
        (params == null || params.isEmpty) && gender == null && sanitizeBiDi;

    if (isStatic) {
      final cached = _staticCache[key];
      if (cached != null) return cached;
    }

    String? translation;

    // 1. If a grammatical gender is active, check gender-suffixed keys
    // e.g. "welcome_female", "welcome_f", "welcome_male", "welcome_m"
    if (targetGender != AppGender.other) {
      final genderSuffixes = [
        '_${targetGender.name}',
        '_${targetGender.name[0]}',
      ];
      for (final suffix in genderSuffixes) {
        final genderKey = '$key$suffix';
        translation = _lookupKey(genderKey);
        if (translation != null) break;
      }
    }

    // 2. Lookup standard base key
    translation ??= _lookupKey(key);

    // Track missing translation keys when unresolvable (ignoring literal tokens)
    if (translation == null) {
      if (!isLiteralToken(key)) {
        _missingKeys.add(key);
        onMissingKey?.call(key, _locale);
      }
    }

    // 3. Fallback: Return the key itself
    final result = translation ?? key;

    final formatted = _format(result, params, sanitizeBiDi);
    if (isStatic) {
      _staticCache[key] = formatted;
    }
    return formatted;
  }

  /// Resolves a gender-aware translation string for [key] given [gender].
  ///
  /// Precedence:
  /// 1. Suffix convention in translations dictionary (e.g. `'key_female'`).
  /// 2. Explicit [forms] map (e.g. `forms['female']`, fallback `forms['other']`).
  /// 3. Fallback to base [key].
  String translateGender(
    String key, {
    AppGender? gender,
    Map<String, String>? forms,
    Map<String, String>? params,
  }) {
    final targetGender = gender ?? _userGender;

    if (forms != null && forms.isNotEmpty) {
      String? resolved =
          forms[targetGender.name] ?? forms[targetGender.name[0]];
      resolved ??= forms['other'] ?? forms['neutral'];
      if (resolved != null) {
        return _format(resolved, params, true);
      }
    }

    return translate(
      key,
      params: params,
      sanitizeBiDi: true,
      gender: targetGender,
    );
  }

  /// Internal key lookup honoring exact locale, language code, fallback locale,
  /// and built-in universal AppCommonTranslations.
  String? _lookupKey(String lookupKey) {
    if (_snapshottedKeys.isEmpty && _translations != null) {
      _snapshottedKeys = _translations!.keys;
    }

    String? val = _snapshottedKeys[_localeExactKey]?[lookupKey];
    if (val != null) return val;

    val = _snapshottedKeys[_localeLangCode]?[lookupKey];
    if (val != null) return val;

    val = _snapshottedKeys[_fallbackExactKey]?[lookupKey];
    if (val != null) return val;

    val = _snapshottedKeys[_fallbackLangCode]?[lookupKey];
    if (val != null) return val;

    // Built-in universal AppCommonTranslations fallback (supports 'close' & 'common_close')
    val = AppCommonTranslations.resolve(lookupKey, _localeLangCode);
    if (val != null) return val;

    return AppCommonTranslations.resolve(lookupKey, _fallbackLangCode);
  }

  /// Resolves a pluralized translation string for [key] given [count].
  ///
  /// Precedence:
  /// 1. Explicit [forms] map (if provided).
  /// 2. Plural-suffixed keys in translations dictionary (e.g. `'cases_two'`, `'cases_few'`).
  /// 3. Suffix `_other` in dictionary (e.g. `'cases_other'`).
  /// 4. Fallback base [key].
  String translatePlural(
    String key,
    num count, {
    Map<String, String>? forms,
    Map<String, String>? params,
  }) {
    // 1. Explicit inline forms map takes precedence if provided
    if (forms != null && forms.isNotEmpty) {
      final resolved = AppPlurals.resolve(_locale.languageCode, count, forms);
      return _format(resolved, params, true);
    }

    // 2. Resolve CLDR plural category for active language and count
    final category = AppPlurals.resolveCategory(_locale.languageCode, count);

    // 3. Lookup plural-suffixed dictionary key:
    // e.g. "cases_zero", "cases_two", "cases_few", "cases_other", "cases"
    String? template;
    if (count == 0) {
      template = _lookupKey('${key}_zero');
    }
    template ??= _lookupKey('${key}_$category') ??
        _lookupKey('${key}_other') ??
        _lookupKey(key);

    template ??= key;

    // 4. Substitute count placeholders
    final countStr = params?['count'] ?? count.toString();
    final withCount = template
        .replaceAll('@count', countStr)
        .replaceAll('{count}', countStr)
        .replaceAll('%d', countStr);

    return _format(withCount, params, true);
  }

  /// Whether to automatically apply Arabic typographic normalization
  /// (Waw conjunction attachment and Arabic punctuation normalization)
  /// on resolved Arabic translations. Defaults to true.
  static bool autoFormatArabic = true;

  /// Interpolates parameters and isolates LTR strings inside RTL sentences.
  String _format(
    String text,
    Map<String, String>? params,
    bool sanitizeBiDi,
  ) {
    final isTemplateRtl =
        AppBidi.isRtlText(text) || (isRtl && AppBidi.hasArabic(text));

    String result = text;

    if (params != null && params.isNotEmpty) {
      params.forEach((key, value) {
        String formattedValue = value;

        // In RTL text templates, isolate parameter values that might cause directional inversion
        if (isTemplateRtl && sanitizeBiDi) {
          formattedValue = AppBidi.autoSanitizeBiDi(
            value,
            isRtlContext: true,
          );
          if (!AppBidi.hasArabic(value) &&
              !value.startsWith(AppBidi.lri) &&
              !value.startsWith(AppBidi.rli)) {
            formattedValue = AppBidi.forceLtr(value);
          }
        }

        result = result
            .replaceAll('@$key', formattedValue)
            .replaceAll('{$key}', formattedValue);
      });
    }

    if (isTemplateRtl && autoFormatArabic) {
      result = AppArabicOrthography.format(
        result,
        fixPunctuation: true,
        fixWaw: true,
        autocorrect:
            false, // Keep dictionary autocorrect explicit via .autocorrectArabic()
      );
    }

    if (sanitizeBiDi) {
      final trimmed = result.trim();
      final isStandaloneTagOrPhone = isRtl &&
          (trimmed.startsWith('#') ||
              trimmed.startsWith('@') ||
              trimmed.startsWith('+'));

      if (isTemplateRtl || isStandaloneTagOrPhone) {
        result = AppBidi.autoSanitizeBiDi(result, isRtlContext: isRtl);
      }
    }

    return sanitizeBiDi
        ? AppBidi.sanitizePunctuation(result, isRtlContext: isTemplateRtl)
        : result;
  }
}
