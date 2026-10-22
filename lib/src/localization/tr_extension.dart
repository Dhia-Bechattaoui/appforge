import 'bidi_utils.dart';
import 'gender.dart';
import 'translations.dart';

/// Convenient localization and BiDi extensions on [String].
extension AppStringLocalizationExtension on String {
  /// Translates the string key using the active locale.
  ///
  /// Example:
  /// ```dart
  /// 'hello'.tr; // 'Hello' or 'مرحباً'
  /// ```
  String get tr => AppLocalization.instance.translate(this);

  /// Translates the string key with dynamic parameter interpolation.
  ///
  /// In RTL contexts, LTR parameters (such as phone numbers or English names)
  /// are automatically isolated using Unicode UAX #9 isolates to prevent
  /// punctuation or sign flipping.
  ///
  /// Example:
  /// ```dart
  /// 'welcome'.trParams({'name': 'Dhia'}); // 'Welcome, Dhia!'
  /// ```
  String trParams(Map<String, String> params) {
    return AppLocalization.instance.translate(this, params: params);
  }

  /// Translates with pluralization support.
  ///
  /// For Arabic, full 6-form pluralization (`zero`, `one`, `two`, `few`, `many`, `other`)
  /// is evaluated according to official Unicode CLDR rules.
  ///
  /// Example:
  /// ```dart
  /// 'items'.trPlural(count, forms: {
  ///   'zero': 'لا توجد عناصر',
  ///   'one': 'عنصر واحد',
  ///   'two': 'عنصران',
  ///   'few': '@count عناصر',
  ///   'many': '@count عنصراً',
  ///   'other': '@count عنصر',
  /// });
  /// ```
  String trPlural(
    num count, {
    Map<String, String>? forms,
    Map<String, String>? params,
  }) {
    return AppLocalization.instance.translatePlural(
      this,
      count,
      forms: forms,
      params: params,
    );
  }

  /// Translates with grammatical gender selection.
  ///
  /// In Arabic, grammatical gender (التذكير والتأنيث) changes sentence morphology,
  /// verb conjugation, and adjective suffixes.
  ///
  /// If [gender] is omitted, defaults to [AppLocalization.userGender].
  ///
  /// Resolution precedence:
  /// 1. Suffix convention in translations dictionary (e.g. `'key_female'` or `'key_male'`).
  /// 2. Explicit [forms] map (e.g. `{'male': '...', 'female': '...', 'other': '...'}`).
  /// 3. Fallback to base key string.
  ///
  /// Example:
  /// ```dart
  /// 'welcome'.trGender(AppGender.female, {'name': 'Fatima'});
  /// 'welcome'.trGender(); // uses App.userGender
  /// ```
  String trGender([
    AppGender? gender,
    Map<String, String>? params,
    Map<String, String>? forms,
  ]) {
    return AppLocalization.instance.translateGender(
      this,
      gender: gender,
      forms: forms,
      params: params,
    );
  }

  /// Translates with grammatical gender selection and explicit forms map.
  ///
  /// Example:
  /// ```dart
  /// 'status'.trGenderForms({
  ///   'male': 'متصل',
  ///   'female': 'متصلة',
  ///   'other': 'متصل',
  /// }, gender: AppGender.female);
  /// ```
  String trGenderForms(
    Map<String, String> forms, {
    AppGender? gender,
    Map<String, String>? params,
  }) {
    return AppLocalization.instance.translateGender(
      this,
      gender: gender,
      forms: forms,
      params: params,
    );
  }

  /// Isolates phone numbers or symbol-prefixed numbers using Unicode Left-to-Right
  /// Isolates (`\u2066` and `\u2069`), ensuring that leading `+` signs and digits
  /// never invert in RTL layouts.
  ///
  /// Example:
  /// ```dart
  /// '+974 5500 1234'.asPhone;
  /// ```
  String get asPhone => AppBidi.isolatePhone(this);

  /// Isolates hashtags, user handles, or symbol-prefixed tokens (e.g. `#AppForge`, `@handle`)
  /// using Unicode isolates so that the leading `#` or `@` never flips to the wrong
  /// end in RTL or LTR contexts.
  ///
  /// Example:
  /// ```dart
  /// '#AppForge'.asTag; // '\u2066#AppForge\u2069'
  /// ```
  String get asTag => AppBidi.isolateTag(this);

  /// Explicitly isolates this string in a Left-to-Right block.
  String get forceLtr => AppBidi.forceLtr(this);

  /// Explicitly isolates this string in a Right-to-Left block.
  String get forceRtl => AppBidi.forceRtl(this);

  /// Converts Western Arabic numerals (0-9) within this string to Eastern Arabic (٠-٩).
  String get toArabicDigits => AppBidi.toArabicDigits(this);

  /// Converts Eastern Arabic numerals (٠-٩) within this string to Western Arabic (0-9).
  String get toWesternDigits => AppBidi.toWesternDigits(this);

  /// Automatically isolates mixed Latin/English script runs within this string
  /// using Unicode UAX #9 isolates when in RTL contexts.
  String get isolateMixed => AppBidi.isolateMixed(this);
}

/// Localization extensions on [num].
extension AppNumLocalizationExtension on num {
  /// Converts this number to Eastern Arabic numerals (e.g. `123` -> `'١٢٣'`).
  String get toArabicDigits => AppBidi.toArabicDigits(toString());
}
