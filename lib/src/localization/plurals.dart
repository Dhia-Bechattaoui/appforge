/// Pluralization engine supporting standard languages and comprehensive
/// 6-form Arabic grammatical rules according to the Unicode CLDR standard.
class AppPlurals {
  AppPlurals._();

  /// Resolves the correct plural string for the given [languageCode] and [count].
  ///
  /// The [forms] map can contain keys:
  /// - `zero`: 0
  /// - `one`: 1 (singular)
  /// - `two`: 2 (dual - مثنى)
  /// - `few`: 3-10 (plural of paucity - جمع قلة)
  /// - `many`: 11-99 (accusative plural - تمييز منصوب)
  /// - `other`: Default fallback form
  ///
  /// Automatically interpolates `@count`, `{count}`, and `%d` with [count].
  static String resolve(
    String languageCode,
    num count,
    Map<String, String> forms,
  ) {
    if (forms.isEmpty) return count.toString();

    String? template;
    if (count == 0 && forms.containsKey('zero')) {
      template = forms['zero'];
    } else {
      final category = resolveCategory(languageCode, count);
      template = forms[category] ?? forms['other'] ?? forms.values.first;
    }

    template ??= forms.values.first;

    return template
        .replaceAll('@count', count.toString())
        .replaceAll('{count}', count.toString())
        .replaceAll('%d', count.toString());
  }

  /// Determines the CLDR plural category for the given language and count.
  static String resolveCategory(String languageCode, num count) {
    final lang = languageCode.toLowerCase();

    if (lang == 'ar') {
      return _resolveArabicCategory(count);
    }

    // Default Germanic/Romance standard (English, French, Spanish, etc.)
    return _resolveStandardCategory(count);
  }

  /// Implements official Unicode CLDR Arabic pluralization rules (6 forms).
  static String _resolveArabicCategory(num count) {
    // CLDR Arabic: Decimals / non-integers always resolve to 'other'
    if (count is double && count != count.truncateToDouble()) {
      return 'other';
    }

    final absCount = count.abs().toInt();
    if (absCount == 0) return 'zero';
    if (absCount == 1) return 'one';
    if (absCount == 2) return 'two';

    final mod100 = absCount % 100;
    if (mod100 >= 3 && mod100 <= 10) {
      return 'few';
    }

    if (mod100 >= 11 && mod100 <= 99) {
      return 'many';
    }

    return 'other';
  }

  /// Standard 2-form pluralization (e.g. English).
  static String _resolveStandardCategory(num count) {
    return (count == 1) ? 'one' : 'other';
  }
}
