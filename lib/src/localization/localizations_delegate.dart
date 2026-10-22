import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'bidi_utils.dart';

/// Universal, zero-dependency localization delegates for Flutter.
///
/// Ensures that [MaterialApp] and its widgets ([Scaffold], [AppBar], buttons, chips)
/// always find [MaterialLocalizations], [WidgetsLocalizations], and
/// [CupertinoLocalizations] for any locale (including Arabic and RTL languages)
/// without requiring external packages.
class AppLocalizationsDelegate {
  AppLocalizationsDelegate._();

  /// Universal [MaterialLocalizations] delegate that supports all locales.
  static const LocalizationsDelegate<MaterialLocalizations> materialDelegate =
      _AppMaterialLocalizationsDelegate();

  /// Universal [WidgetsLocalizations] delegate that supports all locales.
  static const LocalizationsDelegate<WidgetsLocalizations> widgetsDelegate =
      _AppWidgetsLocalizationsDelegate();

  /// Universal [CupertinoLocalizations] delegate that supports all locales.
  static const LocalizationsDelegate<CupertinoLocalizations> cupertinoDelegate =
      _AppCupertinoLocalizationsDelegate();

  /// Combined list of universal zero-dependency delegates ready for [MaterialApp].
  static const List<LocalizationsDelegate<dynamic>> delegates = [
    materialDelegate,
    widgetsDelegate,
    cupertinoDelegate,
  ];
}

class _AppMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AppMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    return DefaultMaterialLocalizations.load(locale);
  }

  @override
  bool shouldReload(_AppMaterialLocalizationsDelegate old) => false;
}

class _AppWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _AppWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    return SynchronousFuture<WidgetsLocalizations>(
      _AppWidgetsLocalizations(locale),
    );
  }

  @override
  bool shouldReload(_AppWidgetsLocalizationsDelegate old) => false;
}

class _AppWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _AppWidgetsLocalizations(this.locale);

  final Locale locale;

  @override
  TextDirection get textDirection =>
      AppBidi.textDirectionForLocale(locale.languageCode);
}

class _AppCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _AppCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    return DefaultCupertinoLocalizations.load(locale);
  }

  @override
  bool shouldReload(_AppCupertinoLocalizationsDelegate old) => false;
}
