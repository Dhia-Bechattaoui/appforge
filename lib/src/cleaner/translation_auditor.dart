import 'dart:convert';
import 'dart:io';
import '../localization/common_translations.dart';
import '../localization/translations.dart';
import 'audit_report.dart';

/// Represents a discovered translation dictionary file in a project.
class DiscoveredTranslationFile {
  const DiscoveredTranslationFile({
    required this.file,
    required this.keysByLocale,
    required this.keyLineNumbers,
  });

  /// The physical file on disk.
  final File file;

  /// Map of locale codes to translation key-value pairs.
  final Map<String, Map<String, String>> keysByLocale;

  /// Map of key names to their line number in the source file (1-indexed).
  final Map<String, int> keyLineNumbers;

  /// All unique translation keys defined in this file.
  Set<String> get allKeys {
    final set = <String>{};
    for (final dict in keysByLocale.values) {
      set.addAll(dict.keys);
    }
    return set;
  }
}

/// Zero-dependency static and runtime translation auditor.
///
/// Detects cross-locale consistency gaps (keys present in one language but missing in another),
/// empty strings, unused (dead) translation keys that bloat memory, and unregistered keys
/// referenced in source code. Provides automated pruning (`pruneUnusedKeys`) to safely remove
/// dead translation keys.
class AppTranslationAuditor {
  AppTranslationAuditor._();

  /// Regex pattern matching translation keys used in source code.
  /// Captures:
  /// 1. Extension syntax: `'key'.tr`, `'key'.trParams`, `'key'.trPlural`, etc.
  /// 2. Functional syntax: `tr('key')`, `App.tr('key')`, `App.trParams('key', ...)`.
  static final RegExp _trCallRegex = RegExp(
    r'''(?:['"])([\w\-]+)(?:['"])\s*\.\s*(?:tr|trParams|trPlural|trGender|trGenderForms)\b|'''
    r'''\b(?:App\.)?(?:tr|trParams|trPlural|trGender)\(\s*['"]([\w\-]+)['"]''',
  );

  /// Performs a fast in-memory cross-locale consistency audit on [translationsOrKeys].
  ///
  /// Accepts either an `AppTranslations` instance or a raw `Map<String, Map<String, String>>`.
  /// Compares every locale against the union of all defined keys and flags
  /// missing keys, empty translation strings, and any [runtimeMissingKeys] requested in code.
  static AppAuditReport auditDictionary(
    Object translationsOrKeys, {
    Iterable<String>? runtimeMissingKeys,
  }) {
    final Map<String, Map<String, String>> keysMap;
    if (translationsOrKeys is Map<String, Map<String, String>>) {
      keysMap = translationsOrKeys;
    } else if (translationsOrKeys is AppTranslations) {
      keysMap = translationsOrKeys.keys;
    } else {
      throw ArgumentError(
        'Expected AppTranslations or Map<String, Map<String, String>>, but got ${translationsOrKeys.runtimeType}',
      );
    }
    final allKeys = <String>{};
    final localeKeys = <String, Set<String>>{};
    final emptyKeys = <String, List<String>>{};

    for (final entry in keysMap.entries) {
      final localeCode = entry.key;
      final dict = entry.value;
      final keysInLocale = <String>{};

      for (final kv in dict.entries) {
        allKeys.add(kv.key);
        keysInLocale.add(kv.key);

        if (kv.value.trim().isEmpty) {
          emptyKeys.putIfAbsent(localeCode, () => []).add(kv.key);
        }
      }

      localeKeys[localeCode] = keysInLocale;
    }

    final missingKeys = <String, List<String>>{};
    for (final entry in localeKeys.entries) {
      final localeCode = entry.key;
      final present = entry.value;
      final missing = allKeys.difference(present).toList()..sort();

      if (missing.isNotEmpty) {
        missingKeys[localeCode] = missing;
      }
    }

    final unregistered = <String>[];
    if (runtimeMissingKeys != null) {
      for (final rk in runtimeMissingKeys) {
        if (!allKeys.contains(rk) &&
            !AppCommonTranslations.isCommonKey(rk) &&
            !AppLocalization.isLiteralToken(rk)) {
          unregistered.add(rk);
        }
      }
    }
    unregistered.sort();

    return AppAuditReport(
      missingKeys: missingKeys,
      emptyKeys: emptyKeys,
      unusedKeys: const [],
      unregisteredKeys: unregistered,
      totalKeysDefined: allKeys.length,
      totalLocales: keysMap.length,
    );
  }

  /// Extracts all translation keys referenced in [sourceCode] using `.tr`,
  /// `.trParams`, `.trPlural`, `.trGender`, `.trGenderForms`, or `App.tr(...)`.
  static Set<String> extractKeysFromSource(String sourceCode) {
    final keys = <String>{};
    final matches = _trCallRegex.allMatches(sourceCode);
    for (final m in matches) {
      final key = m.group(1) ?? m.group(2);
      if (key != null && key.isNotEmpty) {
        keys.add(key);
      }
    }
    return keys;
  }

  /// Recursively scans [dir] for `.dart` files and extracts all referenced translation keys
  /// along with their relative file locations and 1-indexed line numbers.
  static Map<String, List<String>> scanDirectoryWithLocations(
    Directory dir, {
    List<String> ignoredDirectories = const [
      '.git',
      '.dart_tool',
      'build',
      '.idea',
      '.agents',
    ],
  }) {
    final locations = <String, List<String>>{};
    if (!dir.existsSync()) return locations;

    final files = dir.listSync(recursive: true, followLinks: false);
    for (final entity in files) {
      if (entity is File && entity.path.endsWith('.dart')) {
        final pathSegments = entity.uri.pathSegments;
        final isIgnored = ignoredDirectories.any(
          (ignored) => pathSegments.contains(ignored),
        );
        if (isIgnored) continue;

        try {
          final lines = entity.readAsLinesSync();
          final relPath = entity.path.startsWith(dir.path)
              ? entity.path.substring(dir.path.length + 1)
              : entity.path;

          for (int i = 0; i < lines.length; i++) {
            final lineKeys = extractKeysFromSource(lines[i]);
            for (final k in lineKeys) {
              locations.putIfAbsent(k, () => []).add('$relPath:${i + 1}');
            }
          }
        } catch (_) {
          // Skip unreadable files
        }
      }
    }

    return locations;
  }

  /// Recursively scans [dir] for `.dart` files and extracts all referenced translation keys.
  static Set<String> scanDirectory(
    Directory dir, {
    List<String> ignoredDirectories = const [
      '.git',
      '.dart_tool',
      'build',
      '.idea',
      '.agents',
    ],
  }) {
    return scanDirectoryWithLocations(
      dir,
      ignoredDirectories: ignoredDirectories,
    ).keys.toSet();
  }

  /// Scans [dir] to locate translation files (`.dart` classes extending `AppTranslations`
  /// or containing `get keys =>`, or `.json` / `.arb` files).
  static List<DiscoveredTranslationFile> findTranslationFiles(
    Directory dir, {
    List<String> ignoredDirectories = const [
      '.git',
      '.dart_tool',
      'build',
      '.idea',
      '.agents',
      'ios',
      'android',
      'macos',
      'linux',
      'windows',
      'web',
    ],
  }) {
    final discovered = <DiscoveredTranslationFile>[];
    if (!dir.existsSync()) return discovered;

    final files = dir.listSync(recursive: true, followLinks: false);
    for (final entity in files) {
      if (entity is! File) continue;

      final pathSegments = entity.uri.pathSegments;
      final isIgnored = ignoredDirectories.any(
        (ignored) => pathSegments.contains(ignored),
      );
      if (isIgnored) continue;

      if (entity.path.endsWith('.dart')) {
        final parsed = extractFromDartFile(entity);
        if (parsed != null && parsed.allKeys.isNotEmpty) {
          discovered.add(parsed);
        }
      } else if (entity.path.endsWith('.json') ||
          entity.path.endsWith('.arb')) {
        final parsed = extractFromJsonFile(entity);
        if (parsed != null && parsed.allKeys.isNotEmpty) {
          discovered.add(parsed);
        }
      }
    }

    return discovered;
  }

  /// Statically parses a Dart file to extract defined translation keys and line numbers.
  static DiscoveredTranslationFile? extractFromDartFile(File file) {
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      if (!content.contains('AppTranslations') &&
          !content.contains('get keys =>') &&
          !content.contains('get keys=>')) {
        return null;
      }

      final lines = content.split('\n');
      final entryRegex =
          RegExp(r'''^\s*['"]([a-zA-Z0-9_\-]+)['"]\s*:\s*(.*)$''');

      String? currentLocale;
      final keysByLocale = <String, Map<String, String>>{};
      final keyLineNumbers = <String, int>{};

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        final match = entryRegex.firstMatch(line);
        if (match != null) {
          final key = match.group(1)!;
          final rest = match.group(2)!.trim();
          if (rest.startsWith('{')) {
            currentLocale = key;
            keysByLocale.putIfAbsent(currentLocale, () => <String, String>{});
          } else if (currentLocale != null) {
            String val = rest;
            if (val.endsWith(',')) {
              val = val.substring(0, val.length - 1).trim();
            }
            if ((val.startsWith("'") && val.endsWith("'")) ||
                (val.startsWith('"') && val.endsWith('"'))) {
              val = val.substring(1, val.length - 1);
            }
            keysByLocale[currentLocale]![key] = val;
            keyLineNumbers.putIfAbsent(key, () => i + 1);
          }
        }
      }

      return DiscoveredTranslationFile(
        file: file,
        keysByLocale: keysByLocale,
        keyLineNumbers: keyLineNumbers,
      );
    } catch (_) {
      return null;
    }
  }

  /// Statically parses a JSON or ARB translation file.
  static DiscoveredTranslationFile? extractFromJsonFile(File file) {
    if (!file.existsSync()) return null;
    try {
      final content = file.readAsStringSync();
      final decoded = json.decode(content);
      if (decoded is Map) {
        final keys = <String, String>{};
        final keyLines = <String, int>{};
        final lines = content.split('\n');
        for (final entry in decoded.entries) {
          final k = entry.key.toString();
          if (k.startsWith('@')) continue; // Skip ARB metadata
          keys[k] = entry.value.toString();
          final idx =
              lines.indexWhere((l) => l.contains('"$k"') || l.contains("'$k'"));
          if (idx != -1) keyLines[k] = idx + 1;
        }
        final locale = file.uri.pathSegments.last.split('.').first;
        return DiscoveredTranslationFile(
          file: file,
          keysByLocale: {locale: keys},
          keyLineNumbers: keyLines,
        );
      }
    } catch (_) {}
    return null;
  }

  /// Automatically removes [unusedKeys] from [file].
  ///
  /// If [createBackup] is true, a `.bak` copy of the file is created before pruning.
  /// Returns the number of keys successfully removed.
  static int pruneUnusedKeys({
    required File file,
    required Iterable<String> unusedKeys,
    bool createBackup = true,
  }) {
    if (!file.existsSync() || unusedKeys.isEmpty) return 0;
    final keysSet = unusedKeys.toSet();

    if (createBackup) {
      file.copySync('${file.path}.bak');
    }

    final isJson = file.path.endsWith('.json') || file.path.endsWith('.arb');
    if (isJson) {
      try {
        final content = file.readAsStringSync();
        final decoded = json.decode(content);
        if (decoded is Map) {
          int count = 0;
          for (final k in keysSet) {
            if (decoded.containsKey(k)) {
              decoded.remove(k);
              decoded.remove('@$k'); // Also remove ARB metadata
              count++;
            }
          }
          const encoder = JsonEncoder.withIndent('  ');
          file.writeAsStringSync(encoder.convert(decoded));
          return count;
        }
      } catch (_) {
        return 0;
      }
    }

    // Handle Dart files
    final lines = file.readAsLinesSync();
    final entryRegex = RegExp(r'''^\s*['"]([a-zA-Z0-9_\-]+)['"]\s*:\s*(.*)$''');
    final cleaned = <String>[];
    int removedCount = 0;
    bool skippingMultiline = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (skippingMultiline) {
        if (line.contains("'''") || line.contains('"""')) {
          skippingMultiline = false;
        }
        continue;
      }

      final match = entryRegex.firstMatch(line);
      if (match != null) {
        final key = match.group(1)!;
        final rest = match.group(2)!.trim();

        // If it's an unused key and not a locale container (like 'en_US': {)
        if (keysSet.contains(key) && !rest.startsWith('{')) {
          removedCount++;
          // Check if it opened a multiline string that hasn't closed yet
          final openedSingleTriple =
              rest.startsWith("'''") && !rest.substring(3).contains("'''");
          final openedDoubleTriple =
              rest.startsWith('"""') && !rest.substring(3).contains('"""');
          if (openedSingleTriple || openedDoubleTriple) {
            skippingMultiline = true;
          }
          continue; // Pruned!
        }
      }

      cleaned.add(line);
    }

    file.writeAsStringSync(cleaned.join('\n'));
    return removedCount;
  }

  /// Performs a full end-to-end audit by scanning project source code in [rootDir]
  /// and cross-referencing it with [translations].
  static AppAuditReport scanProject({
    required Directory rootDir,
    required Object translations,
    bool includeCommonTranslations = true,
    Iterable<String>? runtimeMissingKeys,
  }) {
    // 1. Audit dictionary consistency (cross-locale gaps & empty keys)
    final dictReport = auditDictionary(
      translations,
      runtimeMissingKeys: runtimeMissingKeys,
    );

    // 2. Scan source code for all keys used with .tr extensions and their locations
    final locationsMap = scanDirectoryWithLocations(rootDir);
    final usedInCode = locationsMap.keys.toSet();

    // 3. Collect all dictionary keys
    final Map<String, Map<String, String>> keysMap;
    if (translations is Map<String, Map<String, String>>) {
      keysMap = translations;
    } else if (translations is AppTranslations) {
      keysMap = translations.keys;
    } else {
      throw ArgumentError(
        'Expected AppTranslations or Map<String, Map<String, String>>, but got ${translations.runtimeType}',
      );
    }
    final definedKeys = <String>{};
    for (final dict in keysMap.values) {
      definedKeys.addAll(dict.keys);
    }

    // Built-in universal translation checker (handles both 'close' and 'common_close')
    final isBuiltIn = includeCommonTranslations
        ? (String k) => AppCommonTranslations.isCommonKey(k)
        : (String k) => false;

    // 4. Identify dead / unused keys defined in dictionary
    final unusedKeys = <String>[];
    for (final key in definedKeys) {
      if (usedInCode.contains(key)) continue;

      // Check if base key was referenced (e.g. 'cases' used for 'cases_zero')
      final basePluralOrGender = _resolveBaseKey(key);
      if (basePluralOrGender != null &&
          usedInCode.contains(basePluralOrGender)) {
        continue;
      }

      unusedKeys.add(key);
    }
    unusedKeys.sort();

    // 5. Identify missing translation keys referenced in code but missing from dictionary
    final unregisteredKeys = <String>[];
    final unregisteredLocations = <String, List<String>>{};
    for (final key in usedInCode) {
      // Check exact match or built-in common term
      if (definedKeys.contains(key) || isBuiltIn(key)) continue;

      // Check if any suffix variant exists in defined keys (e.g. 'cases_zero', 'user_m')
      final hasVariant = definedKeys.any((definedKey) {
        return definedKey.startsWith('${key}_');
      });

      if (!hasVariant) {
        unregisteredKeys.add(key);
        unregisteredLocations[key] = locationsMap[key] ?? const [];
      }
    }

    // Merge any runtime missing keys if passed
    if (runtimeMissingKeys != null) {
      for (final rk in runtimeMissingKeys) {
        if (!unregisteredKeys.contains(rk) &&
            !definedKeys.contains(rk) &&
            !isBuiltIn(rk)) {
          unregisteredKeys.add(rk);
        }
      }
    }
    unregisteredKeys.sort();

    return AppAuditReport(
      missingKeys: dictReport.missingKeys,
      emptyKeys: dictReport.emptyKeys,
      unusedKeys: unusedKeys,
      unregisteredKeys: unregisteredKeys,
      unregisteredKeyLocations: unregisteredLocations,
      totalKeysDefined: dictReport.totalKeysDefined,
      totalLocales: dictReport.totalLocales,
    );
  }

  /// Strips known plural and gender suffixes to find the base key.
  static String? _resolveBaseKey(String key) {
    const suffixes = [
      '_zero',
      '_one',
      '_two',
      '_few',
      '_many',
      '_other',
      '_male',
      '_female',
      '_m',
      '_f',
    ];

    for (final suffix in suffixes) {
      if (key.endsWith(suffix) && key.length > suffix.length) {
        return key.substring(0, key.length - suffix.length);
      }
    }
    return null;
  }
}
