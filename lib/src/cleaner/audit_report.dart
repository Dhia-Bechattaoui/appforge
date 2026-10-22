/// Structured result of an AppForge translation audit.
///
/// Contains details on cross-locale consistency gaps, empty strings,
/// unused (dead) keys defined in the dictionary, and unregistered keys
/// referenced in application code.
class AppAuditReport {
  const AppAuditReport({
    required this.missingKeys,
    required this.emptyKeys,
    required this.unusedKeys,
    required this.unregisteredKeys,
    required this.totalKeysDefined,
    required this.totalLocales,
    this.unregisteredKeyLocations = const {},
  });

  /// Map of locale codes to keys present in other locales but missing in this locale.
  ///
  /// Example:
  /// `{'ar': ['forgot_password', 'terms_conditions']}`
  final Map<String, List<String>> missingKeys;

  /// Map of locale codes to keys that have empty or whitespace-only translation strings.
  final Map<String, List<String>> emptyKeys;

  /// Keys defined in [AppTranslations] that were not found in any scanned `.dart` source files.
  final List<String> unusedKeys;

  /// Keys referenced in source code (e.g. `'welcome'.tr`) that are not defined in any locale.
  final List<String> unregisteredKeys;

  /// Source locations where unregistered keys were detected (e.g. `{'missing_key': ['lib/screen.dart:42']}`).
  final Map<String, List<String>> unregisteredKeyLocations;

  /// Total unique translation keys defined across all locales.
  final int totalKeysDefined;

  /// Total number of locales defined in the dictionary.
  final int totalLocales;

  /// Returns `true` if there are zero missing, empty, unused, or unregistered keys.
  bool get isClean =>
      missingKeys.isEmpty &&
      emptyKeys.isEmpty &&
      unusedKeys.isEmpty &&
      unregisteredKeys.isEmpty;

  /// Total count of all flagged issues.
  int get totalIssues =>
      _countMapIssues(missingKeys) +
      _countMapIssues(emptyKeys) +
      unusedKeys.length +
      unregisteredKeys.length;

  static int _countMapIssues(Map<String, List<String>> map) {
    int count = 0;
    for (final list in map.values) {
      count += list.length;
    }
    return count;
  }

  /// Converts the audit report to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'isClean': isClean,
      'totalIssues': totalIssues,
      'totalKeysDefined': totalKeysDefined,
      'totalLocales': totalLocales,
      'missingKeys': missingKeys,
      'emptyKeys': emptyKeys,
      'unusedKeys': unusedKeys,
      'unregisteredKeys': unregisteredKeys,
      'unregisteredKeyLocations': unregisteredKeyLocations,
    };
  }

  /// Generates a human-readable formatted summary string.
  String get summary {
    final buffer = StringBuffer();
    buffer.writeln('=== AppForge Translation Audit Report ===');
    buffer.writeln('Locales analyzed: $totalLocales');
    buffer.writeln('Total unique keys: $totalKeysDefined');
    buffer.writeln(
        'Status: ${isClean ? "CLEAN (0 issues)" : "FOUND $totalIssues ISSUES"}');
    buffer.writeln('-----------------------------------------');

    if (missingKeys.isNotEmpty) {
      buffer.writeln('\n[!] Missing Keys per Locale (Cross-Locale Gaps):');
      missingKeys.forEach((locale, keys) {
        buffer.writeln('  Locale "$locale" is missing (${keys.length}):');
        for (final k in keys) {
          buffer.writeln('    - $k');
        }
      });
    }

    if (emptyKeys.isNotEmpty) {
      buffer.writeln('\n[!] Empty or Whitespace Translations:');
      emptyKeys.forEach((locale, keys) {
        buffer.writeln('  Locale "$locale" has empty values for:');
        for (final k in keys) {
          buffer.writeln('    - $k');
        }
      });
    }

    if (unregisteredKeys.isNotEmpty) {
      buffer.writeln(
          '\n[!] Missing Translation Keys (Unregistered Keys Used in Code) (${unregisteredKeys.length}):');
      for (final k in unregisteredKeys) {
        final locs = unregisteredKeyLocations[k];
        final locStr =
            locs != null && locs.isNotEmpty ? ' (${locs.join(', ')})' : '';
        buffer.writeln('    - $k$locStr');
      }
    }

    if (unusedKeys.isNotEmpty) {
      buffer.writeln(
          '\n[i] Dead / Unused Keys Defined in Dictionary (${unusedKeys.length}):');
      for (final k in unusedKeys) {
        buffer.writeln('    - $k');
      }
    }

    if (isClean) {
      buffer.writeln(
          '\nAll locales are 100% synchronized and free of dead keys!');
    }

    return buffer.toString();
  }

  @override
  String toString() => summary;
}
