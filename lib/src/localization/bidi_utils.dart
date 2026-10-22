import 'dart:ui' as ui;

/// Bidirectional (BiDi) utilities adhering to the Unicode Bidirectional
/// Algorithm (UAX #9) for handling mixed-direction text, phone numbers,
/// and script direction detection without third-party dependencies.
class AppBidi {
  AppBidi._();

  /// Unicode Left-to-Right Isolate (U+2066).
  ///
  /// Signals to the text rendering engine that following characters must be
  /// isolated and formatted in Left-to-Right direction.
  static const String lri = '\u2066';

  /// Unicode Right-to-Left Isolate (U+2067).
  ///
  /// Signals to the text rendering engine that following characters must be
  /// isolated and formatted in Right-to-Left direction.
  static const String rli = '\u2067';

  /// Unicode First Strong Isolate (U+2068).
  ///
  /// Direction is determined by the first strongly directional character.
  static const String fsi = '\u2068';

  /// Unicode Pop Directional Isolate (U+2069).
  ///
  /// Closes the scope of the most recent [lri], [rli], or [fsi].
  static const String pdi = '\u2069';

  /// Unicode Left-to-Right Mark (U+200E).
  ///
  /// An invisible character with strong LTR directionality.
  static const String lrm = '\u200E';

  /// Unicode Right-to-Left Mark (U+200F).
  ///
  /// An invisible character with strong RTL directionality.
  static const String rlm = '\u200F';

  /// Eastern Arabic (Indic) numerals for conversion.
  static const List<String> _easternArabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];

  /// Isolates a phone number or symbol-prefixed sequence to prevent
  /// symbol/digit flipping in RTL contexts.
  ///
  /// Example:
  /// ```dart
  /// AppBidi.isolatePhone('+974 5500 1234'); // '\u2066+974 5500 1234\u2069'
  /// ```
  static String isolatePhone(String phone) {
    if (phone.isEmpty) return phone;
    return '$lri$phone$pdi';
  }

  /// Isolates hashtags, user handles, or symbol-prefixed tokens (e.g. `#AppForge`, `@user`)
  /// using Unicode Directional Isolates (LRI/RLI and PDI) so that leading symbols (`#`, `@`, `$`, `+`)
  /// remain strictly attached to the correct visual side regardless of ambient RTL/LTR layout.
  ///
  /// Example:
  /// ```dart
  /// AppBidi.isolateTag('#AppForge'); // '\u2066#AppForge\u2069'
  /// ```
  static String isolateTag(String tag) {
    if (tag.isEmpty) return tag;
    if (hasArabic(tag)) {
      return '$rli$tag$pdi';
    }
    return '$lri$tag$pdi';
  }

  /// Forces the given text to be treated as a Left-to-Right isolated block.
  static String forceLtr(String text) {
    if (text.isEmpty) return text;
    return '$lri$text$pdi';
  }

  /// Forces the given text to be treated as a Right-to-Left isolated block.
  static String forceRtl(String text) {
    if (text.isEmpty) return text;
    return '$rli$text$pdi';
  }

  /// Automatically inspects [text] and applies directional isolation (UAX #9)
  /// for hashtags, user handles, phone numbers, and mixed Latin/Arabic text.
  ///
  /// This ensures that calling `.tr` on phone numbers (`+974 5500 1234`),
  /// hashtags (`#AppForge`), and mentions (`@user`) automatically formats
  /// correctly without requiring manual `.asTag` or `.asPhone` calls.
  static String autoSanitizeBiDi(String text, {required bool isRtlContext}) {
    if (text.isEmpty) return text;

    // Already isolated with LRI/RLI
    if (text.startsWith(lri) || text.startsWith(rli)) {
      return text;
    }

    final trimmed = text.trim();

    // 1. Phone number with leading '+'
    if (trimmed.startsWith('+')) {
      return isRtlContext ? isolatePhone(text) : text;
    }

    // 2. Hashtags (#tag) and mentions (@handle)
    if (trimmed.startsWith('#') || trimmed.startsWith('@')) {
      if (isRtlContext) {
        // In RTL, Latin tags (e.g. #AppForge, @user) flip unless isolated as LTR
        if (!hasArabic(trimmed)) {
          return isolateTag(text);
        }
      } else {
        // In LTR, Arabic tags (e.g. #فلاتر) flip unless isolated as RTL
        if (hasArabic(trimmed)) {
          return isolateTag(text);
        }
      }
    }

    // 3. Mixed script text containing Arabic
    if (hasArabic(text)) {
      return isolateMixed(text);
    }

    return text;
  }

  /// Converts Western Arabic numerals (0-9) to Eastern Arabic (Indic) numerals (٠-٩).
  static String toArabicDigits(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final codeUnit = input.codeUnitAt(i);
      // '0' is 48, '9' is 57
      if (codeUnit >= 48 && codeUnit <= 57) {
        buffer.write(_easternArabicDigits[codeUnit - 48]);
      } else {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  /// Converts Eastern Arabic numerals (٠-٩) back to Western Arabic numerals (0-9).
  static String toWesternDigits(String input) {
    if (input.isEmpty) return input;
    final buffer = StringBuffer();
    for (int i = 0; i < input.length; i++) {
      final char = input[i];
      final index = _easternArabicDigits.indexOf(char);
      if (index != -1) {
        buffer.write(index.toString());
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Determines if the provided string contains Arabic characters.
  static bool hasArabic(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (_isArabicCodeUnit(code)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if the first strongly-directional character in [text] is RTL.
  static bool isRtlText(String text) {
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (_isArabicCodeUnit(code) || _isHebrewCodeUnit(code)) {
        return true;
      }
      if (_isLatinCodeUnit(code)) {
        return false;
      }
    }
    return false;
  }

  /// Returns [ui.TextDirection.rtl] if the locale or text is RTL, otherwise [ui.TextDirection.ltr].
  static ui.TextDirection textDirectionForLocale(String languageCode) {
    const rtlLanguages = {'ar', 'fa', 'ur', 'he', 'ps', 'sd', 'ug', 'yi'};
    return rtlLanguages.contains(languageCode.toLowerCase())
        ? ui.TextDirection.rtl
        : ui.TextDirection.ltr;
  }

  /// Sanitizes mixed-direction strings where neutral trailing punctuation
  /// (e.g. `!`, `?`, `.`, `:`) might visually jump to the wrong side
  /// in RTL environments when ending with a Latin character.
  static String sanitizePunctuation(String text, {bool isRtlContext = true}) {
    if (text.isEmpty) return text;
    if (!isRtlContext) return text;

    final lastChar = text[text.length - 1];
    const punctuation = {'!', '?', '.', ':', '؛', '،'};

    if (punctuation.contains(lastChar)) {
      // Append RLM so the trailing punctuation remains bounded to the RTL flow.
      return '$text$rlm';
    }
    return text;
  }

  /// Detects and isolates Latin script runs within an RTL context using LRI/PDI (UAX #9).
  ///
  /// This ensures mixed Arabic+Latin strings (e.g. `النمط الحالي: system`)
  /// render in the correct visual order without requiring manual Unicode markers.
  static String isolateMixed(String text) {
    if (text.isEmpty) return text;
    // If there is no Arabic (RTL) content, return unchanged.
    if (!hasArabic(text)) return text;

    final buffer = StringBuffer();
    final length = text.length;
    int i = 0;

    while (i < length) {
      final char = text[i];

      // If already isolated with LRI/RLI/FSI, preserve it up to PDI
      if (char == lri || char == rli || char == fsi) {
        final pdiIndex = text.indexOf(pdi, i + 1);
        if (pdiIndex != -1) {
          buffer.write(text.substring(i, pdiIndex + 1));
          i = pdiIndex + 1;
          continue;
        }
      }

      // If we encounter a Latin character or a symbol-prefixed Latin/numeric token (like #tag, @user, +phone)
      final code = text.codeUnitAt(i);
      final isPrefixSymbol =
          (char == '#' || char == '@' || char == '+' || char == r'$') &&
              (i + 1 < length &&
                  (_isLatinCodeUnit(text.codeUnitAt(i + 1)) ||
                      (text.codeUnitAt(i + 1) >= 48 &&
                          text.codeUnitAt(i + 1) <= 57)));

      if (_isLatinCodeUnit(code) || isPrefixSymbol) {
        final start = i;
        if (isPrefixSymbol) i++;
        while (i < length) {
          final c = text.codeUnitAt(i);
          final ch = text[i];
          if (_isLatinCodeUnit(c) ||
              (c >= 48 && c <= 57) || // digits 0-9
              ch == '.' ||
              ch == '_' ||
              ch == '-' ||
              ch == '@' ||
              ch == '#' ||
              ch == '/' ||
              ch == ':') {
            // Do not swallow trailing punctuation at end of segment
            if ((ch == ':' || ch == '.') &&
                (i + 1 == length ||
                    text[i + 1] == ' ' ||
                    _isArabicCodeUnit(text.codeUnitAt(i + 1)))) {
              break;
            }
            i++;
          } else {
            break;
          }
        }
        final segment = text.substring(start, i);
        buffer.write('$lri$segment$pdi');
      } else {
        buffer.write(char);
        i++;
      }
    }

    return buffer.toString();
  }

  static bool _isArabicCodeUnit(int code) {
    return (code >= 0x0600 && code <= 0x06FF) || // Arabic
        (code >= 0x0750 && code <= 0x077F) || // Arabic Supplement
        (code >= 0x08A0 && code <= 0x08FF) || // Arabic Extended-A
        (code >= 0xFB50 && code <= 0xFDFF) || // Arabic Presentation Forms-A
        (code >= 0xFE70 && code <= 0xFEFF); // Arabic Presentation Forms-B
  }

  static bool _isHebrewCodeUnit(int code) {
    return code >= 0x0590 && code <= 0x05FF;
  }

  static bool _isLatinCodeUnit(int code) {
    return (code >= 0x0041 && code <= 0x005A) || // A-Z
        (code >= 0x0061 && code <= 0x007A); // a-z
  }
}
