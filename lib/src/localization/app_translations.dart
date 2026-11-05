/// Base contract for app translations dictionary.
///
/// Designed to be pure Dart with zero Flutter/UI dependencies so that
/// static analysis, code generation, and CLI tools can run outside Flutter.
abstract class AppTranslations {
  const AppTranslations();

  static final RegExp _phoneNumberRegex = RegExp(
    r'^\+?[0-9]{1,4}?[-.\s]?(\(?[0-9]{1,3}?\)?[-.\s]?)?[0-9]{1,4}[-.\s]?[0-9]{1,4}[-.\s]?[0-9]{1,9}$',
  );
  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Determines whether [key] is a literal UI token (such as a hashtag, handle,
  /// URL, phone number, or email address) rather than a translatable dictionary key.
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

  /// Map of locale keys to key-value translation pairs.
  Map<String, Map<String, String>> get keys;

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
