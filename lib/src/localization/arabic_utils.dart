/// Advanced Arabic text processing, Tashkeel (diacritics) handling,
/// normalization, and automated grammatical gender inflection.
library;

import 'gender.dart';

/// Utilities for processing Arabic typography, diacritics (التشكيل),
/// and grammatical pronoun inflection without third-party dependencies.
class AppArabic {
  AppArabic._();

  /// Arabic Tashkeel / Harakat Unicode character range:
  /// - Fatha (\u064E), Kasra (\u0650), Damma (\u064F)
  /// - Tanwin Fath (\u064B), Tanwin Damm (\u064C), Tanwin Kasr (\u064D)
  /// - Sukun (\u0652), Shadda (\u0651), Dagger Alif (\u0670)
  static final RegExp tashkeelRegex = RegExp(
    r'[\u064B-\u0652\u0670]',
  );

  /// Arabic Tatweel / Kashida (\u0640) character.
  static final RegExp tatweelRegex = RegExp(r'\u0640');

  /// Strips all Arabic Tashkeel (diacritics: فَتْحَة، كَسْرَة، ضَمَّة، تَنْوِين، شَدَّة، سُكُون).
  ///
  /// Example:
  /// ```dart
  /// AppArabic.stripTashkeel('مَرْحَباً بِكُمْ'); // 'مرحبا بكم'
  /// ```
  static String stripTashkeel(String input) {
    if (input.isEmpty) return input;
    return input.replaceAll(tashkeelRegex, '');
  }

  /// Removes Arabic Tatweel / Kashida (ـ) stretching characters.
  ///
  /// Example:
  /// ```dart
  /// AppArabic.stripTatweel('مــلــف'); // 'ملف'
  /// ```
  static String stripTatweel(String input) {
    if (input.isEmpty) return input;
    return input.replaceAll(tatweelRegex, '');
  }

  /// Normalizes Arabic text for searching, indexing, and fuzzy comparison.
  ///
  /// Performs:
  /// 1. Strips Tashkeel (diacritics).
  /// 2. Strips Tatweel (ـ).
  /// 3. Normalizes Hamza variants (`[أإآٱ]` -> `ا`).
  /// 4. Normalizes final Taa' Marboota (`ة` -> `ه`).
  /// 5. Normalizes Alif Maqsoora (`ى` -> `ي`).
  ///
  /// Example:
  /// ```dart
  /// AppArabic.normalize('إِلَى مَرْكَزِ التَّطْوِيرِ'); // 'الي مركز التطوير'
  /// ```
  static String normalize(String input) {
    if (input.isEmpty) return input;

    var result = stripTashkeel(input);
    result = stripTatweel(result);

    // Normalizing Alif forms: أ, إ, آ, ٱ -> ا
    result = result.replaceAll(RegExp(r'[أإآٱ]'), 'ا');

    // Normalizing Taa' Marboota to Haa
    result = result.replaceAll('ة', 'ه');

    // Normalizing Alif Maqsoora to Yaa
    result = result.replaceAll('ى', 'ي');

    return result;
  }

  /// Performs diacritic-insensitive and orthography-insensitive fuzzy search.
  ///
  /// Matches even if [source] has Harakat/Tatweel and [query] is bare text.
  ///
  /// Example:
  /// ```dart
  /// AppArabic.fuzzyContains('مَرْحَباً بِكَ', 'مرحبا'); // true
  /// ```
  static bool fuzzyContains(String source, String query) {
    if (query.isEmpty) return true;
    if (source.isEmpty) return false;

    final normSource = normalize(source).toLowerCase();
    final normQuery = normalize(query).toLowerCase();

    return normSource.contains(normQuery);
  }

  /// Registered custom user gender inflection pairs
  static final List<List<String>> _customGenderPairs = [];

  /// Registers custom male/female pairs for Arabic gender inflection.
  ///
  /// Each pair must be formatted as `[maleForm, femaleForm]`.
  ///
  /// Example:
  /// ```dart
  /// AppArabic.registerGenderPairs([
  ///   ['كابتن', 'كابتنة'],
  ///   ['طبيبنا', 'طبيبتنا'],
  ///   ['مبرمج', 'مبرمجة'],
  /// ]);
  /// ```
  static void registerGenderPairs(List<List<String>> pairs) {
    _customGenderPairs.addAll(pairs);
  }

  /// Clears all custom user-registered gender inflection pairs.
  static void clearCustomGenderPairs() {
    _customGenderPairs.clear();
  }

  /// Automatically inflects second-person pronouns and suffixes in an Arabic
  /// sentence or paragraph according to [targetGender].
  ///
  /// When converting to [AppGender.female]:
  /// - `لكَ` -> `لكِ`, `بكَ` -> `بكِ`, `منكَ` -> `منكِ`
  /// - `عَلَيْكَ` / `عليك` -> `عليكِ`
  /// - `إلَيْكَ` / `إليك` -> `إليكِ`
  /// - `مَعَكَ` / `معك` -> `معكِ`
  /// - `فِيكَ` / `فيك` -> `فيكِ`
  /// - `عِنْدَكَ` / `عندك` -> `عندكِ`
  /// - `أَنْتَ` / `أنت` -> `أنتِ`
  /// - Words ending with Kaf-Fatha (`كَ`) -> replaced by Kaf-Kasra (`كِ`).
  ///
  /// When converting to [AppGender.male]:
  /// - `لكِ` -> `لكَ`, `بكِ` -> `بكَ`, `أنتِ` -> `أنتَ`, etc.
  ///
  /// Example:
  /// ```dart
  /// final msg = 'شكراً لكَ يا @name، يسعدنا تواصلكَ معنا.';
  /// AppArabic.inflectGender(msg, AppGender.female);
  /// // -> 'شكراً لكِ يا @name، يسعدنا تواصلكِ معنا.'
  /// ```
  static String inflectGender(
    String text,
    AppGender targetGender, {
    List<List<String>>? customPairs,
  }) {
    if (text.isEmpty || targetGender == AppGender.other) return text;

    if (targetGender == AppGender.female) {
      return _inflectToFemale(text, customPairs: customPairs);
    } else {
      return _inflectToMale(text, customPairs: customPairs);
    }
  }

  static String _inflectToFemale(
    String input, {
    List<List<String>>? customPairs,
  }) {
    var result = input;

    // 1. Any word ending with Kaf-Fatha (كَ) -> Kaf-Kasra (كِ)
    result = result.replaceAllMapped(
      RegExp(r'([\u0621-\u0652\u0670])كَ([^\u0621-\u0652\u0670]|$)'),
      (m) => '${m.group(1)}كِ${m.group(2) ?? ''}',
    );

    // 2. Custom pairs (per-call and globally registered)
    if (customPairs != null) {
      for (final pair in customPairs) {
        if (pair.length >= 2) {
          result = _replaceArabicPronoun(result, pair[0], pair[1]);
        }
      }
    }
    for (final pair in _customGenderPairs) {
      if (pair.length >= 2) {
        result = _replaceArabicPronoun(result, pair[0], pair[1]);
      }
    }

    // 3. Specific pronouns and particles (with optional و/ف prefixes)
    final pronounPairs = [
      ['أَنْتَ', 'أَنْتِ'],
      ['أنتَ', 'أنتِ'],
      ['أنت', 'أنتِ'],
      ['لَكَ', 'لَكِ'],
      ['لكَ', 'لكِ'],
      ['لك', 'لكِ'],
      ['بِكَ', 'بِكِ'],
      ['بكَ', 'بكِ'],
      ['بك', 'بكِ'],
      ['مِنْكَ', 'مِنْكِ'],
      ['منكَ', 'منكِ'],
      ['منك', 'منكِ'],
      ['عَلَيْكَ', 'عَلَيْكِ'],
      ['عَليكَ', 'عليكِ'],
      ['عليك', 'عليكِ'],
      ['إِلَيْكَ', 'إِلَيْكِ'],
      ['إليكَ', 'إليكِ'],
      ['إليك', 'إليكِ'],
      ['مَعَكَ', 'مَعَكِ'],
      ['معكَ', 'معكِ'],
      ['معك', 'معكِ'],
      ['فِيكَ', 'فِيكِ'],
      ['فيكَ', 'فيكِ'],
      ['فيك', 'فيكِ'],
      ['عِنْدَكَ', 'عِنْدَكِ'],
      ['عندكَ', 'عندكِ'],
      ['عندك', 'عندكِ'],
    ];

    for (final pair in pronounPairs) {
      result = _replaceArabicPronoun(result, pair[0], pair[1]);
    }

    // 3. Relational and vocative address (صديقي -> صديقتي، أخي -> أختي)
    for (final pair in _relationalAndVocativePairs) {
      result = _replaceArabicPronoun(result, pair[0], pair[1]);
    }

    // 4. Predicate nouns and adjectives (عضو مميز -> عضوة مميزة)
    for (final pair in _predicatePairs) {
      result = _replaceArabicPronoun(result, pair[0], pair[1]);
    }

    // 5. Common user imperative verbs (اضغط -> اضغطي، شارك -> شاركي)
    for (final pair in _imperativePairs) {
      result = _replaceArabicPronoun(result, pair[0], pair[1]);
    }

    // 6. Second-person present tense verbs (تستطيع -> تستطيعين)
    for (final pair in _presentTensePairs) {
      result = _replaceArabicPronoun(result, pair[0], pair[1]);
    }

    // Collapse any accidental duplicate harakat
    result = result.replaceAllMapped(
      RegExp(r'([\u064B-\u0652\u0670])\1+'),
      (m) => m[1]!,
    );

    return result;
  }

  static String _inflectToMale(
    String input, {
    List<List<String>>? customPairs,
  }) {
    var result = input;

    // 1. Any word ending with Kaf-Kasra (كِ) -> Kaf-Fatha (كَ)
    result = result.replaceAllMapped(
      RegExp(r'([\u0621-\u0652\u0670])كِ([^\u0621-\u0652\u0670]|$)'),
      (m) => '${m.group(1)}كَ${m.group(2) ?? ''}',
    );

    // 2. Custom pairs (per-call and globally registered)
    if (customPairs != null) {
      for (final pair in customPairs) {
        if (pair.length >= 2) {
          result = _replaceArabicPronoun(result, pair[1], pair[0]);
        }
      }
    }
    for (final pair in _customGenderPairs) {
      if (pair.length >= 2) {
        result = _replaceArabicPronoun(result, pair[1], pair[0]);
      }
    }

    // 3. Specific pronouns and particles (with optional و/ف prefixes)
    final pronounPairs = [
      ['أَنْتِ', 'أَنْتَ'],
      ['أنتِ', 'أنتَ'],
      ['لَكِ', 'لَكَ'],
      ['لكِ', 'لكَ'],
      ['بِكِ', 'بِكَ'],
      ['بكِ', 'بكَ'],
      ['مِنْكِ', 'مِنْكَ'],
      ['منكِ', 'منكَ'],
      ['عَلَيْكِ', 'عَلَيْكَ'],
      ['عليكِ', 'عليك'],
      ['إِلَيْكِ', 'إِلَيْكَ'],
      ['إليكِ', 'إليك'],
      ['مَعَكِ', 'مَعَكَ'],
      ['معكِ', 'معك'],
      ['فِيكِ', 'فِيكَ'],
      ['فيكِ', 'فيك'],
      ['عِنْدَكِ', 'عِنْدَكَ'],
      ['عندكِ', 'عندك'],
    ];

    for (final pair in pronounPairs) {
      result = _replaceArabicPronoun(result, pair[0], pair[1]);
    }

    // 3. Relational and vocative address (صديقتي -> صديقي، أختي -> أخي)
    for (final pair in _relationalAndVocativePairs) {
      result = _replaceArabicPronoun(result, pair[1], pair[0]);
    }

    // 4. Predicate nouns and adjectives (عضوة مميزة -> عضو مميز)
    for (final pair in _predicatePairs) {
      result = _replaceArabicPronoun(result, pair[1], pair[0]);
    }

    // 5. Common user imperative verbs (اضغطي -> اضغط، شاركي -> شارك)
    for (final pair in _imperativePairs) {
      result = _replaceArabicPronoun(result, pair[1], pair[0]);
    }

    // 6. Second-person present tense verbs (تستطيعين -> تستطيع)
    for (final pair in _presentTensePairs) {
      result = _replaceArabicPronoun(result, pair[1], pair[0]);
    }

    // Collapse any accidental duplicate harakat
    result = result.replaceAllMapped(
      RegExp(r'([\u064B-\u0652\u0670])\1+'),
      (m) => m[1]!,
    );

    return result;
  }

  /// Relational and vocative nouns with Yaa' al-Mutakallim or Naa'
  static final List<List<String>> _relationalAndVocativePairs = [
    ['صديقي', 'صديقتي'],
    ['صديقنا', 'صديقتنا'],
    ['أخي', 'أختي'],
    ['أخونا', 'أختنا'],
    ['زميلي', 'زميلتي'],
    ['زميلنا', 'زميلتنا'],
    ['أستاذي', 'أستاذتي'],
    ['أستاذنا', 'أستاذتنا'],
    ['عزيزي', 'عزيزتي'],
    ['عزيزنا', 'عزيزتنا'],
    ['حبيبي', 'حبيبتي'],
    ['رفيقي', 'رفيقتي'],
    ['رفيقنا', 'رفيقتنا'],
    ['متابعي', 'متابعتي'],
    ['عميلي', 'عميلتي'],
    ['عميلنا', 'عميلتنا'],
    ['بطلنا', 'بطلتنا'],
    ['مديري', 'مديرتي'],
    ['مديرنا', 'مديرتنا'],
    ['قائدنا', 'قائدتنا'],
    ['شريكي', 'شريكتي'],
    ['شريكنا', 'شريكتنا'],
  ];

  /// Predicate nouns and adjectives agreeing with 2nd person subject
  static final List<List<String>> _predicatePairs = [
    ['عضو مميز', 'عضوة مميزة'],
    ['عضو نشط', 'عضوة نشطة'],
    ['عضو فعال', 'عضوة فعالة'],
    ['عضو جديد', 'عضوة جديدة'],
    ['عضو موثق', 'عضوة موثقة'],
    ['مستخدم جديد', 'مستخدمة جديدة'],
    ['مستخدم مميز', 'مستخدمة مميزة'],
    ['مستخدم نشط', 'مستخدمة نشطة'],
    ['عميل مميز', 'عميلة مميزة'],
    ['مشترك نشط', 'مشتركة نشطة'],
    ['مشترك جديد', 'مشتركة جديدة'],
    ['فائز محظوظ', 'فائزة محظوظة'],
    ['قائد فريق', 'قائدة فريق'],
    ['بطل خارق', 'بطلة خارقة'],
    ['عضو', 'عضوة'],
    ['مميز', 'مميزة'],
    ['رائع', 'رائعة'],
    ['مبدع', 'مبدعة'],
    ['نشط', 'نشطة'],
    ['مستعد', 'مستعدة'],
    ['جاهز', 'جاهزة'],
    ['متصل', 'متصلة'],
    ['مسجل', 'مسجلة'],
    ['مؤهل', 'مؤهلة'],
    ['مسؤول', 'مسؤولة'],
    ['ناجح', 'ناجحة'],
    ['سعيد', 'سعيدة'],
    ['صادق', 'صادقة'],
    ['محبوب', 'محبوبة'],
  ];

  /// Common user imperative UI verbs
  static final List<List<String>> _imperativePairs = [
    ['اضغط', 'اضغطي'],
    ['إضغط', 'اضغطي'],
    ['انقر', 'انقري'],
    ['ادخل', 'ادخلي'],
    ['إدخل', 'ادخلي'],
    ['افتح', 'افتحي'],
    ['أرسل', 'أرسلي'],
    ['ارسل', 'أرسلي'],
    ['تأكد', 'تأكدي'],
    ['تاكد', 'تأكدي'],
    ['شارك', 'شاركي'],
    ['سجل', 'سجلي'],
    ['تفضل', 'تفضلي'],
    ['راجع', 'راجعي'],
    ['اختر', 'اختاري'],
    ['احفظ', 'احفظي'],
    ['انضم', 'انضمي'],
    ['حدث', 'حدثي'],
    ['تابع', 'تابعي'],
    ['تواصل', 'تواصلي'],
    ['قم', 'قومي'],
    ['ابدأ', 'ابدئي'],
    ['جرب', 'جربي'],
    ['استمتع', 'استمتعي'],
  ];

  /// Common user 2nd-person present tense verbs
  static final List<List<String>> _presentTensePairs = [
    ['تستطيع', 'تستطيعين'],
    ['تريد', 'تريدين'],
    ['ترغب', 'ترغبين'],
    ['تحتاج', 'تحتاجين'],
    ['تبحث', 'تبحثين'],
    ['تفضل', 'تفضلين'],
    ['تشارك', 'تشاركين'],
    ['تسجل', 'تسجلين'],
    ['تستخدم', 'تستخدمين'],
    ['تحصل', 'تحصلين'],
    ['تتمكن', 'تتمكنين'],
  ];

  static String _replaceArabicPronoun(
    String input,
    String target,
    String replacement,
  ) {
    final prefixPattern =
        target.startsWith('ال') ? r'([وف]?)' : r'([وف]?ال|[وف]?)';
    final pattern = RegExp(
      '(^|[^\\u0621-\\u0652\\u0670])$prefixPattern$target([^\\u0621-\\u0652\\u0670]|\$)',
    );
    return input.replaceAllMapped(pattern, (m) {
      final prefix = m.group(1) ?? '';
      final conj = m.group(2) ?? '';
      final suffix = m.group(3) ?? '';
      return '$prefix$conj$replacement$suffix';
    });
  }
}

/// Extensions on [String] for convenient Arabic text operations.
extension AppArabicStringExtension on String {
  /// Strips all Arabic Tashkeel (diacritics).
  String get stripTashkeel => AppArabic.stripTashkeel(this);

  /// Strips Arabic Tatweel / Kashida (ـ).
  String get stripTatweel => AppArabic.stripTatweel(this);

  /// Normalizes Arabic text for search and indexing.
  String get normalizeArabic => AppArabic.normalize(this);

  /// Automatically inflects second-person pronouns in this Arabic string based on [gender].
  ///
  /// Optionally accepts [customPairs] for per-call custom male/female pairs.
  String inflectArabicGender(
    AppGender gender, {
    List<List<String>>? customPairs,
  }) =>
      AppArabic.inflectGender(this, gender, customPairs: customPairs);

  /// Diacritic-insensitive and orthography-insensitive fuzzy search.
  bool fuzzyContainsArabic(String query) =>
      AppArabic.fuzzyContains(this, query);
}
