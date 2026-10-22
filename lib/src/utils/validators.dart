final RegExp _emailRegex = RegExp(
  r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
);

final RegExp _phoneCleanRegex = RegExp(r'[\s\-()]');

final RegExp _phonePatternRegex = RegExp(
  r'^\+?[0-9\u0660-\u0669]{7,15}$',
);

final RegExp _arabicIndicRegex = RegExp(r'[\u0660-\u0669]');

String _normalizeDigits(String input) {
  var s = input.replaceAll('\u066B', '.'); // Arabic decimal separator
  if (!s.contains(_arabicIndicRegex)) return s;
  return s.replaceAllMapped(_arabicIndicRegex, (m) {
    final code = m.group(0)!.codeUnitAt(0);
    return String.fromCharCode(0x30 + (code - 0x0660));
  });
}

/// Common string validation extensions for form handling.
extension AppValidationExtension on String {
  /// Whether this string is a valid email address.
  bool get isValidEmail {
    final trimmed = trim();
    if (trimmed.isEmpty) return false;
    return _emailRegex.hasMatch(trimmed);
  }

  /// Whether this string is a valid international or local phone number.
  ///
  /// Supports numbers with leading `+`, country code, spaces, dashes, and digits
  /// (both Western `0-9` and Arabic-Indic `٠-٩`).
  bool get isValidPhone {
    final cleaned = replaceAll(_phoneCleanRegex, '');
    if (cleaned.isEmpty) return false;
    return _phonePatternRegex.hasMatch(cleaned);
  }

  /// Whether this string satisfies a minimum character length requirement.
  bool hasMinLength(int min) => trim().length >= min;

  /// Whether this string satisfies a maximum character length requirement.
  bool hasMaxLength(int max) => trim().length <= max;

  /// Whether this string consists strictly of numeric digits and standard decimal/signs.
  ///
  /// Rejects `NaN`, `Infinity`, and scientific notation (`1e5`). Supports both
  /// Western `0-9` and Arabic-Indic `٠-٩` digits.
  bool get isNumeric {
    final trimmed = trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    if (lower.contains('nan') || lower.contains('inf') || lower.contains('e')) {
      return false;
    }
    final normalized = _normalizeDigits(trimmed);
    final parsed = num.tryParse(normalized);
    return parsed != null && !parsed.isNaN && !parsed.isInfinite;
  }

  /// Capitalizes the first letter of this string.
  String get capitalizeFirst {
    final trimmed = trim();
    if (trimmed.isEmpty) return this;
    final first = this[0].toUpperCase();
    if (length == 1) return first;
    return '$first${substring(1)}';
  }
}
