import 'package:flutter/services.dart';
import 'orthography.dart';

/// A pro-level Flutter [TextInputFormatter] that formats, autocorrects,
/// and normalizes Arabic text in real time as the user types.
///
/// Features:
/// - **Punctuation conversion**: Converts `,` -> `،`, `?` -> `؟`, `;` -> `؛`.
/// - **Punctuation spacing**: Removes space before punctuation, ensures space after.
/// - **Waw attachment**: Attaches floating ` و ` conjunction directly to the word.
/// - **Real-time Autocorrect**: Corrects high-frequency typos (Hamza, Taa' Marboota)
///   upon word boundaries (spaces/punctuation).
///
/// Example:
/// ```dart
/// TextField(
///   inputFormatters: [
///     ArabicTextInputFormatter(
///       fixWawSpacing: true,
///       fixPunctuation: true,
///       autoCorrectCommonWords: true,
///     ),
///   ],
/// )
/// ```
class ArabicTextInputFormatter extends TextInputFormatter {
  /// Whether to attach floating Waw conjunctions (` و ` -> ` و`).
  final bool fixWawSpacing;

  /// Whether to normalize punctuation marks (`,` -> `،`, `?` -> `؟`) and their spacing.
  final bool fixPunctuation;

  /// Whether to autocorrect common Hamza and Taa' Marboota typos upon word completion.
  final bool autoCorrectCommonWords;

  const ArabicTextInputFormatter({
    this.fixWawSpacing = true,
    this.fixPunctuation = true,
    this.autoCorrectCommonWords = true,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Apply orthographic corrections
    final formattedText = AppArabicOrthography.format(
      newValue.text,
      fixPunctuation: fixPunctuation,
      fixWaw: fixWawSpacing,
      autocorrect: autoCorrectCommonWords,
    );

    // If no changes were made, keep original selection
    if (formattedText == newValue.text) {
      return newValue;
    }

    // Calculate updated cursor position
    final lengthDiff = formattedText.length - newValue.text.length;
    final newCursor = (newValue.selection.end + lengthDiff).clamp(
      0,
      formattedText.length,
    );

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
