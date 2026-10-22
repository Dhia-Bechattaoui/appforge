import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';

/// Zero-dependency environment configuration loader and parser.
///
/// Loads and parses `.env` files into strongly typed variables with support for
/// variable expansion (`${VAR}`), multi-line quoted strings, comments, and bash-style `export` syntax.
///
/// > [!WARNING]
/// > **Security Notice**: `.env` files bundled inside Flutter `assets:` are distributed
/// > as unencrypted plain text inside compiled application bundles (APK and IPA).
/// > For production cryptographic secrets, private certificates, and sensitive credentials,
/// > use Flutter's compile-time `--dart-define-from-file=.env` or platform-native keystores.
///
/// Example:
/// ```dart
/// await AppEnv.load();
/// final baseUrl = AppEnv.get('BASE_URL', defaultValue: 'https://api.com');
/// final port = AppEnv.getInt('PORT', defaultValue: 8080);
/// final isDev = AppEnv.getBool('IS_DEV', defaultValue: false);
/// ```
class AppEnv {
  AppEnv._();

  static final Map<String, String> _env = <String, String>{};

  /// Unmodifiable map of all currently loaded environment variables.
  static Map<String, String> get map => Map<String, String>.unmodifiable(_env);

  /// Whether any environment variables have been loaded into memory.
  static bool get isLoaded => _env.isNotEmpty;

  /// Loads and parses an environment file into memory.
  ///
  /// Searches [fileName] via [bundle] or [rootBundle]. In pure Dart test or CLI
  /// environments where Flutter bindings are inactive, automatically falls back
  /// to local filesystem [File] loading.
  ///
  /// Set [isOptional] to `true` to silently continue without error if the file does not exist.
  static Future<void> load({
    String fileName = '.env',
    AssetBundle? bundle,
    bool isOptional = false,
  }) async {
    String? content;

    // 1. Try loading through Flutter AssetBundle
    try {
      final activeBundle = bundle ?? rootBundle;
      content = await activeBundle.loadString(fileName);
    } catch (_) {
      // 2. Fall back to local file system (useful in tests, desktop & CLI)
      try {
        final file = File(fileName);
        if (file.existsSync()) {
          content = await file.readAsString();
        }
      } catch (_) {
        // Ignored
      }
    }

    if (content == null || content.trim().isEmpty) {
      if (!isOptional) {
        throw StateError(
          'AppEnv: Environment file "$fileName" not found or empty. '
          'Ensure it exists in project root or is declared under "assets:" in pubspec.yaml.',
        );
      }
      return;
    }

    loadFromString(content);
  }

  /// Parses and loads environment variables directly from raw [content].
  static void loadFromString(String content, {bool overwrite = true}) {
    final parsed = parse(content);
    if (overwrite) {
      _env.addAll(parsed);
    } else {
      for (final entry in parsed.entries) {
        _env.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  /// Directly registers a key-value [map] into the active environment.
  static void loadFromMap(Map<String, String> map, {bool overwrite = true}) {
    if (overwrite) {
      _env.addAll(map);
    } else {
      for (final entry in map.entries) {
        _env.putIfAbsent(entry.key, () => entry.value);
      }
    }
  }

  /// Clears all loaded environment variables from memory.
  static void clear() {
    _env.clear();
  }

  /// Retrieves a string environment variable by [key], returning [defaultValue] if not found.
  static String get(String key, {String defaultValue = ''}) {
    return _env[key] ?? defaultValue;
  }

  /// Retrieves a string environment variable by [key], returning `null` if not found.
  static String? getOrNull(String key) {
    return _env[key];
  }

  /// Retrieves an integer environment variable by [key].
  static int getInt(String key, {int defaultValue = 0}) {
    final val = _env[key];
    if (val == null) return defaultValue;
    return int.tryParse(val) ?? defaultValue;
  }

  /// Retrieves a double-precision floating-point environment variable by [key].
  static double getDouble(String key, {double defaultValue = 0.0}) {
    final val = _env[key];
    if (val == null) return defaultValue;
    return double.tryParse(val) ?? defaultValue;
  }

  /// Retrieves a boolean environment variable by [key].
  ///
  /// Evaluates `'true'`, `'1'`, `'yes'`, `'on'`, `'enabled'` (case-insensitive) as `true`.
  /// Evaluates `'false'`, `'0'`, `'no'`, `'off'`, `'disabled'` (case-insensitive) as `false`.
  /// Returns [defaultValue] if the key is missing or unparseable.
  static bool getBool(String key, {bool defaultValue = false}) {
    final val = _env[key]?.trim().toLowerCase();
    if (val == null || val.isEmpty) return defaultValue;

    if (val == 'true' ||
        val == '1' ||
        val == 'yes' ||
        val == 'on' ||
        val == 'enabled') {
      return true;
    }
    if (val == 'false' ||
        val == '0' ||
        val == 'no' ||
        val == 'off' ||
        val == 'disabled') {
      return false;
    }
    return defaultValue;
  }

  /// Returns whether [key] exists in the loaded environment.
  static bool contains(String key) => _env.containsKey(key);

  /// Generates a sanitized debugging string with sensitive keys masked.
  static String debugSummary({
    Set<String> sensitiveKeywords = const {
      'KEY',
      'SECRET',
      'PASSWORD',
      'PASS',
      'TOKEN',
      'AUTH',
      'API',
      'PRIVATE',
      'CREDENTIAL',
    },
  }) {
    final buffer = StringBuffer();
    buffer.writeln('=== AppEnv Configuration (${_env.length} variables) ===');
    for (final entry in _env.entries) {
      final isSensitive = sensitiveKeywords.any(
        (kw) => entry.key.toUpperCase().contains(kw),
      );
      final displayValue = isSensitive ? _maskValue(entry.value) : entry.value;
      buffer.writeln('  ${entry.key} = $displayValue');
    }
    return buffer.toString();
  }

  /// Returns a sanitized map copy where sensitive values are masked.
  static Map<String, String> maskedMap({
    Set<String> sensitiveKeywords = const {
      'KEY',
      'SECRET',
      'PASSWORD',
      'PASS',
      'TOKEN',
      'AUTH',
      'API',
      'PRIVATE',
      'CREDENTIAL',
    },
  }) {
    final result = <String, String>{};
    for (final entry in _env.entries) {
      final isSensitive = sensitiveKeywords.any(
        (kw) => entry.key.toUpperCase().contains(kw),
      );
      result[entry.key] = isSensitive ? _maskValue(entry.value) : entry.value;
    }
    return result;
  }

  static String _maskValue(String val) {
    if (val.length <= 4) return '****';
    return '${val.substring(0, 2)}****${val.substring(val.length - 2)}';
  }

  /// Pure parser that converts raw `.env` formatted text into a key-value map.
  ///
  /// Pure parser that converts raw `.env` formatted text into a key-value map.
  ///
  /// Supports:
  /// - Strip leading `export ` keyword
  /// - Stripping `#` comments and inline `#` outside quotes
  /// - Single (`'...'`) quotes: literal values, zero variable expansion, zero escape expansion
  /// - Double (`"..."`) quotes: escape sequence expansion and variable expansion
  /// - Multi-line strings in quotes
  /// - Variable interpolation (`${VAR}` and `$VAR`), preserving undefined variable tokens
  static Map<String, String> parse(String content) {
    final result = <String, String>{};
    // Normalize Windows CRLF and CR line endings to standard LF
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = normalized.split('\n');
    final literalKeys = <String>{};

    String? multilineKey;
    String? multilineQuoteChar;
    final multilineBuffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // Handle ongoing multiline string
      if (multilineKey != null) {
        final quoteChar = multilineQuoteChar!;
        final closingIndex = _findClosingQuote(line, quoteChar);

        if (closingIndex != -1) {
          multilineBuffer.write('\n');
          multilineBuffer.write(line.substring(0, closingIndex));
          final isSingleQuoted = quoteChar == "'";
          result[multilineKey] = _unescape(
            multilineBuffer.toString(),
            !isSingleQuoted,
          );
          if (isSingleQuoted) {
            literalKeys.add(multilineKey);
          }
          multilineKey = null;
          multilineQuoteChar = null;
          multilineBuffer.clear();
        } else {
          multilineBuffer.write('\n');
          multilineBuffer.write(line);
        }
        continue;
      }

      line = line.trim();

      // Skip empty lines and full comment lines
      if (line.isEmpty || line.startsWith('#')) continue;

      // Strip optional leading 'export '
      if (line.startsWith('export ') && line.length > 7) {
        line = line.substring(7).trim();
      }

      final equalsIndex = line.indexOf('=');
      if (equalsIndex <= 0) continue;

      final key = line.substring(0, equalsIndex).trim();
      if (!_isValidKey(key)) continue;

      String rawValue = line.substring(equalsIndex + 1).trim();

      // Check if value starts with quote
      if (rawValue.isNotEmpty &&
          (rawValue.startsWith('"') || rawValue.startsWith("'"))) {
        final quoteChar = rawValue[0];
        final isSingleQuoted = quoteChar == "'";
        final valueAfterQuote = rawValue.substring(1);
        final closingIndex = _findClosingQuote(valueAfterQuote, quoteChar);

        if (closingIndex != -1) {
          // Single-line quoted value
          final innerValue = valueAfterQuote.substring(0, closingIndex);
          result[key] = _unescape(innerValue, !isSingleQuoted);
          if (isSingleQuoted) {
            literalKeys.add(key);
          }
        } else {
          // Multi-line quoted value started
          multilineKey = key;
          multilineQuoteChar = quoteChar;
          multilineBuffer.write(valueAfterQuote);
        }
      } else {
        // Unquoted value: Strip inline comments
        final commentIndex = rawValue.indexOf('#');
        if (commentIndex != -1) {
          rawValue = rawValue.substring(0, commentIndex).trim();
        }
        result[key] = rawValue;
      }
    }

    // Second pass: Variable expansion (${VAR} / $VAR)
    return _interpolateVariables(result, literalKeys);
  }

  static bool _isValidKey(String key) {
    if (key.isEmpty) return false;
    for (int i = 0; i < key.length; i++) {
      final code = key.codeUnitAt(i);
      final isAlpha = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
      final isNum = code >= 48 && code <= 57;
      final isSpecial = code == 95 || code == 45; // '_' or '-'
      if (!isAlpha && !isNum && !isSpecial) return false;
    }
    return true;
  }

  static int _findClosingQuote(String text, String quoteChar) {
    for (int i = 0; i < text.length; i++) {
      if (text[i] == quoteChar) {
        // Ensure not escaped with backslash
        int backslashes = 0;
        int j = i - 1;
        while (j >= 0 && text[j] == '\\') {
          backslashes++;
          j--;
        }
        if (backslashes % 2 == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  static final RegExp _escapeRegex = RegExp(r'''\\([\\nrt"'\$])''');

  static String _unescape(String val, bool expandEscapes) {
    if (!expandEscapes) return val;
    return val.replaceAllMapped(_escapeRegex, (match) {
      switch (match.group(1)) {
        case 'n':
          return '\n';
        case 'r':
          return '\r';
        case 't':
          return '\t';
        case '"':
          return '"';
        case "'":
          return "'";
        case r'\':
          return r'\';
        case r'$':
          return r'$';
        default:
          return match.group(0)!;
      }
    });
  }

  static final RegExp _variableRegex =
      RegExp(r'\$\{([a-zA-Z0-9_\-]+)\}|\$([a-zA-Z0-9_\-]+)');

  static Map<String, String> _interpolateVariables(
    Map<String, String> raw,
    Set<String> literalKeys,
  ) {
    final interpolated = <String, String>{};

    for (final entry in raw.entries) {
      // Single-quoted values are literal bash values: never expand $ or ${}
      if (literalKeys.contains(entry.key)) {
        interpolated[entry.key] = entry.value;
        continue;
      }

      String val = entry.value;
      val = val.replaceAllMapped(_variableRegex, (match) {
        final varName = match.group(1) ?? match.group(2)!;
        // If variable is defined, expand it. If undefined, preserve original token ($100, $NOT_FOUND)
        final resolved = interpolated[varName] ?? raw[varName];
        return resolved ?? match.group(0)!;
      });
      interpolated[entry.key] = val;
    }

    return interpolated;
  }
}
