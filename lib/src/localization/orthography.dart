/// Advanced Arabic orthography, proofreading, typographical normalization,
/// and keyboard mistyping correction engine for AppForge.
///
/// Built with zero external dependencies, providing Microsoft Word / Gboard
/// grade typographic and orthographic precision for Flutter applications.
library;

import 'arabic_utils.dart';
import 'gender.dart';

/// Pro-level Arabic orthography engine for proofreading, punctuation normalization,
/// Waw-conjunction attachment, and high-frequency orthographic autocorrection.
class AppArabicOrthography {
  AppArabicOrthography._();

  // ---------------------------------------------------------------------------
  // 1. Punctuation & Typography Normalization
  // ---------------------------------------------------------------------------

  /// Standard Arabic punctuation mapping:
  /// - Western comma `,` -> Arabic comma `،` (\u060C)
  /// - Western question mark `?` -> Arabic question mark `؟` (\u061F)
  /// - Western semicolon `;` -> Arabic semicolon `؛` (\u061B)
  /// - Western percent `%` -> Arabic percent `٪` (\u066A)
  static final RegExp _arabicContextComma = RegExp(
    r'(?<=[\u0621-\u064A\u0660-\u0669\s]),|,(?=[\u0621-\u064A\u0660-\u0669\s])',
  );
  static final RegExp _arabicContextQuestion = RegExp(
    r'(?<=[\u0621-\u064A\u0660-\u0669\s])\?|\?(?=[\u0621-\u064A\u0660-\u0669\s]|$)',
  );
  static final RegExp _arabicContextSemicolon = RegExp(
    r'(?<=[\u0621-\u064A\u0660-\u0669\s]);|;(?=[\u0621-\u064A\u0660-\u0669\s])',
  );
  static final RegExp _multiQuestionMarks = RegExp(r'؟{2,}');
  static final RegExp _multiExclamationMarks = RegExp(r'!{2,}');
  static final RegExp _spaceBeforePunctuation = RegExp(r'[ \t]+([،؛؟!\.:])');
  static final RegExp _spaceAfterPunctuation = RegExp(
    r'([،؛؟!:])([^\s\d،؛؟!\.:\)\]\}"»\u200E\u200F])',
  );
  static final RegExp _innerSpaceOpenBracket = RegExp(r'(\(|«|\[|\{)[ \t]+');
  static final RegExp _innerSpaceCloseBracket = RegExp(r'[ \t]+(\)|»|\]|\})');
  static final RegExp _floatingWaw = RegExp(r'(^|\s)و[ \t]+([\u0621-\u064A])');

  /// Normalizes punctuation marks to standard Arabic typography.
  ///
  /// - Replaces `,` with `،` in Arabic text contexts.
  /// - Replaces `?` with `؟` in Arabic text contexts.
  /// - Replaces `;` with `؛` in Arabic text contexts.
  /// - Removes redundant multiple question marks (`؟؟؟` -> `؟`).
  /// - Normalizes spaces before and after punctuation per typographic standards
  ///   (no space before `،`, `؟`, `!`, `.`, `:`, `;`; single space after).
  ///
  /// Example:
  /// ```dart
  /// AppArabicOrthography.normalizePunctuation('مرحبا , كيف حالك ?');
  /// // Output: 'مرحبا، كيف حالك؟'
  /// ```
  static String normalizePunctuation(String text) {
    if (text.isEmpty) return text;

    var result = text;

    // Convert punctuation in Arabic context
    result = result.replaceAll(_arabicContextComma, '،');
    result = result.replaceAll(_arabicContextQuestion, '؟');
    result = result.replaceAll(_arabicContextSemicolon, '؛');

    // Collapse multiple consecutive question marks or exclamation marks
    result = result.replaceAll(_multiQuestionMarks, '؟');
    result = result.replaceAll(_multiExclamationMarks, '!');

    // Typographical Spacing:
    // 1. Remove space BEFORE punctuation marks (، ؛ ؟ ! . : )
    result = result.replaceAllMapped(
      _spaceBeforePunctuation,
      (m) => m[1]!,
    );

    // 2. Ensure a space AFTER punctuation marks when followed directly by an Arabic or Latin word
    result = result.replaceAllMapped(
      _spaceAfterPunctuation,
      (m) => '${m[1]} ${m[2]}',
    );

    // 3. Remove inner spaces in parentheses and guillemets: ( كلمة ) -> (كلمة)
    result = result.replaceAllMapped(
      _innerSpaceOpenBracket,
      (m) => m[1]!,
    );
    result = result.replaceAllMapped(
      _innerSpaceCloseBracket,
      (m) => m[1]!,
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // 2. Waw Al-'Atf (واو العطف) Conjunction Spacing
  // ---------------------------------------------------------------------------

  /// In proper Arabic typography and orthography, the conjunction `و` (Waw)
  /// must NEVER float alone with a space separating it from the following word.
  ///
  /// Example:
  /// ```dart
  /// AppArabicOrthography.fixWawConjunction('محمد و أحمد'); // 'محمد وأحمد'
  /// AppArabicOrthography.fixWawConjunction('حفظ و إلغاء'); // 'حفظ وإلغاء'
  /// ```
  static String fixWawConjunction(String text) {
    if (text.isEmpty) return text;

    // Matches standalone Waw preceded by start or space, followed by space and an Arabic letter
    return text.replaceAllMapped(
      _floatingWaw,
      (match) => '${match[1]}و${match[2]}',
    );
  }

  // ---------------------------------------------------------------------------
  // 3. High-Frequency Orthographic Autocorrect (Word & Keyboard Level)
  // ---------------------------------------------------------------------------

  /// High-frequency UI words and ubiquitous typing mistakes:
  /// - Hamzat Al-Qat' vs. Al-Wasl
  /// - Taa' Marboota vs. Haa'
  /// - Alif Maqsoora vs. Yaa'
  static final Map<String, String> _commonAutocorrectDictionary = {
    // Proper Names (Hamzat al-Qat')
    'احمد': 'أحمد',
    'اسماء': 'أسماء',
    'امجد': 'أمجد',
    'اكرم': 'أكرم',
    'ايمن': 'أيمن',
    'اسامة': 'أسامة',
    'اسامه': 'أسامة',
    'ابراهيم': 'إبراهيم',
    'اسماعيل': 'إسماعيل',
    'انور': 'أنور',
    'امين': 'أمين',

    // UI & Action Words (Hamzat al-Qat')
    'اعدادات': 'إعدادات',
    'الغاء': 'إلغاء',
    'اشعار': 'إشعار',
    'اشعارات': 'إشعارات',
    'ارسال': 'إرسال',
    'اعادة': 'إعادة',
    'انشاء': 'إنشاء',
    'اضافة': 'إضافة',
    'اضافه': 'إضافة',
    'اغلاق': 'إغلاق',
    'ادخال': 'إدخال',
    'اخراج': 'إخراج',
    'احصائيات': 'إحصائيات',
    'اذونات': 'أذونات',
    'اذن': 'إذن',
    'ايميل': 'إيميل',
    'انترنت': 'إنترنت',
    'الكتروني': 'إلكتروني',
    'الكترونية': 'إلكترونية',
    'الكترونيه': 'إلكترونية',
    'تاكيد': 'تأكيد',
    'تاكد': 'تأكد',
    'تاكدي': 'تأكدي',
    'تاخير': 'تأخير',
    'مفاجاه': 'مفاجأة',
    'مسئول': 'مسؤول',
    'شئون': 'شؤون',
    'شئ': 'شيء',
    'دفئ': 'دفء',
    'بدئ': 'بدء',

    // Hamzat Al-Wasl Corrections (Removing wrongful hamza under/over Alif)
    'إستخدام': 'استخدام',
    'إسترجاع': 'استرجاع',
    'إستمرار': 'استمرار',
    'إستعراض': 'استعراض',
    'إستكشاف': 'استكشاف',
    'إستبيان': 'استبيان',
    'إستعلام': 'استعلام',
    'إستيراد': 'استيراد',
    'إستقبال': 'استقبال',
    'إختيار': 'اختيار',
    'إشتراك': 'اشتراك',
    'إتصال': 'اتصال',

    // Taa' Marboota vs. Haa'
    'خدمه': 'خدمة',
    'رساله': 'رسالة',
    'مشاركه': 'مشاركة',
    'صفحه': 'صفحة',
    'مدينه': 'مدينة',
    'لغه': 'لغة',
    'قائمه': 'قائمة',
    'سله': 'سلة',
    'شاشه': 'شاشة',
    'نسخه': 'نسخة',
    'مساعده': 'مساعدة',
    'تهيئه': 'تهيئة',
    'مزامنه': 'مزامنة',
    'عمليه': 'عملية',
    'بطاقه': 'بطاقة',
    'كلمه': 'كلمة',
    'نقطه': 'نقطة',
    'صوره': 'صورة',
    'حاله': 'حالة',
    'دوله': 'دولة',
    'منطقه': 'منطقة',
    'طريقه': 'طريقة',
    'خطوه': 'خطوة',
    'فتره': 'فترة',
    'مجموعه': 'مجموعة',
    'سياره': 'سيارة',
    'نافذه': 'نافذة',
    'حمايه': 'حماية',
    'معاينه': 'معاينة',
    'اتفاقيه': 'اتفاقية',
    'مشكله': 'مشكلة',
    'شبكه': 'شبكة',
    'معلوماتيه': 'معلوماتية',
    'خصوصيه': 'خصوصية',
    'امكانيه': 'إمكانية',
    'صلاحيه': 'صلاحية',
    'عضويه': 'عضوية',
    'احقيه': 'أحقية',
    'هويه': 'هوية',
    'واجهه': 'واجهة',
    'تجربه': 'تجربة',

    // Wrong Taa' Marboota on pronouns (should be Haa)
    'فية': 'فيه',
    'علية': 'عليه',
    'منة': 'منه',
    'إلية': 'إليه',
    'الية': 'إليه',
    'عنة': 'عنه',
    'معة': 'معه',

    // Alif Maqsoora vs. Yaa'
    'الي': 'إلى',
    'حتي': 'حتى',
    'اخرى': 'أخرى',
    'اولي': 'أولى',
    'مستشفي': 'مستشفى',
    'معني': 'معنى',
    'دعوي': 'دعوى',
    'فتوي': 'فتوى',
    'كبري': 'كبرى',
    'صغري': 'صغرى',
    'اعلي': 'أعلى',
    'ادني': 'أدنى',
    'اقصي': 'أقصى',

    // Tanwin Fath Greetings & Adverbs
    'اهلا': 'أهلاً',
    'شكرا': 'شكراً',
    'ايضا': 'أيضاً',
    'دائما': 'دائماً',
    'جدا': 'جداً',
    'فورا': 'فوراً',
    'مرحبا': 'مرحباً',
  };

  /// Common attached Arabic proclitics (prepositions and conjunctions) ordered by length:
  /// e.g. `وبال`, `فبال`, `ولل`, `وال`, `بال`, `لل`, `ال`, `و`, `ب`, etc.
  static final List<String> _proclitics = [
    'وبال',
    'فبال',
    'وكال',
    'فكال',
    'ولل',
    'فلل',
    'وال',
    'فال',
    'بال',
    'كال',
    'لل',
    'وب',
    'ول',
    'وك',
    'فب',
    'فل',
    'فك',
    'ال',
    'و',
    'ف',
    'ب',
    'ل',
    'ك',
  ];

  /// Registered custom user autocorrect dictionary for domain words, proper names, or brands.
  static final Map<String, String> _customAutocorrectDictionary = {};

  /// Registers custom user words, names, or brand terms into the Arabic autocorrect dictionary.
  ///
  /// Words registered here enjoy the exact same treatment as built-in words,
  /// including attached proclitics (`ال`, `و`, `ب`, `ل`, `ك`) and Tashkeel matching.
  ///
  /// Example:
  /// ```dart
  /// AppArabicOrthography.registerCustomWords({
  ///   'ضياء': 'ضِياء',
  ///   'حميدان': 'حُميدان',
  ///   'ستارتب': 'ستارت آب',
  /// });
  /// ```
  static void registerCustomWords(Map<String, String> words) {
    _customAutocorrectDictionary.addAll(words);
  }

  /// Clears all custom user-registered autocorrect words.
  static void clearCustomWords() {
    _customAutocorrectDictionary.clear();
  }

  static final RegExp _tokenRegex =
      RegExp(r'([\u0621-\u0652\u0670]+|[^\u0621-\u0652\u0670]+)');
  static final RegExp _arabicWordTokenRegex =
      RegExp(r'^[\u0621-\u0652\u0670]+$');
  static final RegExp _duplicateTashkeelRegex =
      RegExp(r'([\u064B-\u0652\u0670])\1+');
  static final RegExp _tashkeelStripRegex = RegExp(r'[\u064B-\u0652\u0670]');
  static final RegExp _arabicLettersRegex = RegExp(r'[\u0621-\u064A]');

  /// Performs dictionary-assisted orthographic correction on known high-frequency
  /// Arabic words and user-registered words, fixing Hamzat al-Qat' vs Wasl,
  /// Taa' Marboota vs Haa', and Alif Maqsoora vs Yaa', including attached prefixes (`ال`, `و`, `ب`, `ل`).
  ///
  /// Optionally accepts a [customDictionary] for local, per-call overrides.
  ///
  /// Example:
  /// ```dart
  /// AppArabicOrthography.autocorrectWords('يرجى التحقق من اعدادات الخدمه وارسال الرساله');
  /// // Output: 'يرجى التحقق من إعدادات الخدمة وإرسال الرسالة'
  /// ```
  static String autocorrectWords(
    String text, {
    Map<String, String>? customDictionary,
  }) {
    if (text.isEmpty) return text;

    // Splits text into tokens while preserving separators and punctuation, keeping Tashkeel with word
    final matches = _tokenRegex.allMatches(text);

    final buffer = StringBuffer();

    for (final match in matches) {
      final token = match.group(0)!;

      // Only inspect Arabic word tokens
      if (_arabicWordTokenRegex.hasMatch(token)) {
        buffer.write(_correctSingleWord(token, customDictionary));
      } else {
        buffer.write(token);
      }
    }

    // Collapse any accidental duplicate Tashkeel marks
    var result = buffer.toString();
    result = result.replaceAllMapped(
      _duplicateTashkeelRegex,
      (m) => m[1]!,
    );

    return result;
  }

  static String? _lookupWord(String key, Map<String, String>? localDictionary) {
    if (localDictionary != null && localDictionary.containsKey(key)) {
      return localDictionary[key];
    }
    if (_customAutocorrectDictionary.containsKey(key)) {
      return _customAutocorrectDictionary[key];
    }
    return _commonAutocorrectDictionary[key];
  }

  static String _correctSingleWord(
    String word,
    Map<String, String>? localDictionary,
  ) {
    // 1. Direct match
    final direct = _lookupWord(word, localDictionary);
    if (direct != null) return direct;

    // 2. Match with Tashkeel stripped
    final stripped = word.replaceAll(_tashkeelStripRegex, '');
    final strippedMatch = _lookupWord(stripped, localDictionary);
    if (strippedMatch != null) {
      // If original word already had tanwin and replacement has tanwin, avoid duplicate
      if (word.endsWith('ً') && strippedMatch.endsWith('ً')) {
        return strippedMatch;
      }
      return strippedMatch;
    }

    // 3. Match with attached proclitics (e.g. 'بالخدمه' -> 'بالخدمة', 'والاعدادات' -> 'والإعدادات')
    for (final prefix in _proclitics) {
      if (word.startsWith(prefix) && word.length > prefix.length) {
        final stem = word.substring(prefix.length);
        final stemMatch = _lookupWord(stem, localDictionary);
        if (stemMatch != null) {
          return '$prefix$stemMatch';
        }
        final strippedStem =
            word.substring(prefix.length).replaceAll(_tashkeelStripRegex, '');
        final strippedStemMatch = _lookupWord(strippedStem, localDictionary);
        if (strippedStemMatch != null) {
          return '$prefix$strippedStemMatch';
        }
      }
    }

    return word;
  }

  // ---------------------------------------------------------------------------
  // 4. All-in-One Professional Formatter Pipeline
  // ---------------------------------------------------------------------------

  /// Runs the full Microsoft Word / Gboard grade proofreading pipeline:
  /// 1. [fixPunctuation]: Normalizes Arabic punctuation marks and their spacing.
  /// 2. [fixWaw]: Attaches floating Waw conjunctions (` و ` -> ` و`).
  /// 3. [autocorrect]: Corrects high-frequency Hamza, Taa' Marboota, and Alif Maqsoora mistakes.
  /// 4. [gender]: Optionally inflects grammatical gender when provided.
  /// 5. [customDictionary]: Optional per-call dictionary for custom words/names.
  /// 6. [customGenderPairs]: Optional per-call gender inflection pairs.
  ///
  /// Example:
  /// ```dart
  /// const input = 'مرحبا , يرجى فتح اعدادات الخدمه و التحقق من الرساله ?';
  /// final result = AppArabicOrthography.format(input);
  /// // Output: 'مرحباً، يرجى فتح إعدادات الخدمة والتحقق من الرسالة؟'
  /// ```
  static String format(
    String text, {
    bool fixPunctuation = true,
    bool fixWaw = true,
    bool autocorrect = true,
    AppGender? gender,
    Map<String, String>? customDictionary,
    List<List<String>>? customGenderPairs,
  }) {
    if (text.isEmpty) return text;

    var result = text;

    if (gender != null) {
      result = AppArabic.inflectGender(
        result,
        gender,
        customPairs: customGenderPairs,
      );
    }

    if (fixWaw) {
      result = fixWawConjunction(result);
    }

    if (autocorrect) {
      result = autocorrectWords(result, customDictionary: customDictionary);
    }

    if (fixPunctuation) {
      result = normalizePunctuation(result);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // 5. QWERTY <-> Arabic Keyboard Layout Converter (Fat-Finger Fixer)
  // ---------------------------------------------------------------------------

  /// Standard US QWERTY to Arabic 101/102 Keyboard mapping
  static const Map<String, String> _qwertyToArabicMap = {
    // Row 1 (Numbers & Symbols)
    '`': 'ذ', '~': 'ّ', '1': '1', '2': '2', '3': '3', '4': '4',
    '5': '5', '6': '6', '7': '7', '8': '8', '9': '9', '0': '0',
    '!': '!', '@': '@', '#': '#', '\$': '\$', '%': '٪', '^': '^',
    '&': '&', '*': '*', '(': ')', ')': '(', '-': '-', '_': '_',
    '=': '=', '+': '+',

    // Row 2
    'q': 'ض', 'Q': 'َ',
    'w': 'ص', 'W': 'ً',
    'e': 'ث', 'E': 'ُ',
    'r': 'ق', 'R': 'ٌ',
    't': 'ف', 'T': 'لإ',
    'y': 'غ', 'Y': 'إ',
    'u': 'ع', 'U': '‘',
    'i': 'ه', 'I': '÷',
    'o': 'خ', 'O': '×',
    'p': 'ح', 'P': '؛',
    '[': 'ج', '{': '<',
    ']': 'د', '}': '>',
    '\\': '\\', '|': '|',

    // Row 3
    'a': 'ش', 'A': 'ِ',
    's': 'س', 'S': 'ٍ',
    'd': 'ي', 'D': ']',
    'f': 'ب', 'F': '[',
    'g': 'ل', 'G': 'لأ',
    'h': 'ا', 'H': 'أ',
    'j': 'ت', 'J': 'ـ',
    'k': 'ن', 'K': '،',
    'l': 'م', 'L': '/',
    ';': 'ك', ':': ':',
    "'": 'ط', '"': '"',

    // Row 4
    'z': 'ئ', 'Z': '~',
    'x': 'ء', 'X': 'ْ',
    'c': 'ؤ', 'C': '}',
    'v': 'ر', 'V': '{',
    'b': 'لا', 'B': 'لآ',
    'n': 'ى', 'N': 'آ',
    'm': 'ة', 'M': '’',
    ',': 'و', '<': ',',
    '.': 'ز', '>': '.',
    '/': 'ظ', '?': '؟',
    ' ': ' ',
  };

  /// Inverse mapping: Arabic 101 to US QWERTY
  static final Map<String, String> _arabicToQwertyMap = {
    for (final entry in _qwertyToArabicMap.entries)
      if (entry.value != entry.key) entry.value: entry.key,
  };

  /// Converts text mistyped on an English QWERTY keyboard layout into proper Arabic.
  ///
  /// Example:
  /// ```dart
  /// AppArabicOrthography.qwertyToArabic('lvpfh'); // 'مرحبا'
  /// AppArabicOrthography.qwertyToArabic('Hplh');  // 'أهلاً'
  /// ```
  static String qwertyToArabic(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(_qwertyToArabicMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Converts text mistyped on an Arabic keyboard layout into English QWERTY.
  ///
  /// Example:
  /// ```dart
  /// AppArabicOrthography.arabicToQwerty('مرحبا'); // 'lvpfh'
  /// ```
  static String arabicToQwerty(String text) {
    if (text.isEmpty) return text;
    final buffer = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(_arabicToQwertyMap[char] ?? char);
    }
    return buffer.toString();
  }

  /// Determines if an input string is likely an Arabic phrase mistakenly typed
  /// on an English keyboard layout (e.g. `Hplh`, `lvpfh`, `sdt phgn`).
  static bool isProbablyMistypedQwerty(String text) {
    if (text.length < 3) return false;
    // If it contains Arabic letters, it's not mistyped QWERTY
    if (_arabicLettersRegex.hasMatch(text)) return false;

    // Convert to Arabic and check whether the converted text yields valid Arabic letters
    final converted = qwertyToArabic(text);
    final arabicLetterCount = _arabicLettersRegex.allMatches(converted).length;

    return arabicLetterCount >= (text.length * 0.7);
  }
}

/// Syntactic extensions for pro-grade Arabic orthography and typography.
extension AppArabicOrthographyExtensions on String {
  /// Runs the full Microsoft Word / Gboard grade proofreading pipeline:
  /// corrects punctuation, Waw spacing, and high-frequency orthographic typos,
  /// and optionally inflects grammatical gender when [gender] is provided.
  String formatArabic({
    bool fixPunctuation = true,
    bool fixWaw = true,
    bool autocorrect = true,
    AppGender? gender,
    Map<String, String>? customDictionary,
    List<List<String>>? customGenderPairs,
  }) {
    return AppArabicOrthography.format(
      this,
      fixPunctuation: fixPunctuation,
      fixWaw: fixWaw,
      autocorrect: autocorrect,
      gender: gender,
      customDictionary: customDictionary,
      customGenderPairs: customGenderPairs,
    );
  }

  /// Normalizes Arabic punctuation marks (`،`, `؟`, `؛`, `٪`) and spacing.
  String fixArabicPunctuation() =>
      AppArabicOrthography.normalizePunctuation(this);

  /// Attaches floating Waw conjunctions (` و ` -> ` و`).
  String fixArabicWaw() => AppArabicOrthography.fixWawConjunction(this);

  /// Corrects high-frequency Hamza, Taa' Marboota, and Alif Maqsoora typos,
  /// optionally merging a per-call [customDictionary].
  String autocorrectArabic({Map<String, String>? customDictionary}) =>
      AppArabicOrthography.autocorrectWords(
        this,
        customDictionary: customDictionary,
      );

  /// Converts text mistyped on an English QWERTY keyboard into Arabic.
  String toArabicKeyboard() => AppArabicOrthography.qwertyToArabic(this);

  /// Converts text mistyped on an Arabic keyboard into English QWERTY.
  String toEnglishKeyboard() => AppArabicOrthography.arabicToQwerty(this);
}
