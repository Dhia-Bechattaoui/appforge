/// Grammatical gender specifications for gender-aware localization.
library;

/// Represents grammatical gender for gender-aware localization.
///
/// In Arabic (التذكير والتأنيث) and morphologically rich languages,
/// grammatical gender dictates verb conjugations, adjective forms,
/// pronouns, and preposition suffixes.
enum AppGender {
  /// Masculine form (المذكر).
  male,

  /// Feminine form (المؤنث).
  female,

  /// Neutral, collective, or unspecified fallback form (المحايد / العام).
  other;

  /// Parses a string into an [AppGender].
  ///
  /// Supports common international and Arabic representations:
  /// - Male: `'male'`, `'m'`, `'masculine'`, `'ذكر'`, `'مذكر'`
  /// - Female: `'female'`, `'f'`, `'feminine'`, `'أنثى'`, `'مؤنث'`
  /// - Other: `'other'`, `'neutral'`, `'n'`, `'عام'`, `'محايد'`
  static AppGender fromString(String? value) {
    if (value == null) return AppGender.other;
    final normalized = value.trim().toLowerCase();
    switch (normalized) {
      case 'male':
      case 'm':
      case 'masculine':
      case 'ذكر':
      case 'مذكر':
        return AppGender.male;
      case 'female':
      case 'f':
      case 'feminine':
      case 'أنثى':
      case 'مؤنث':
        return AppGender.female;
      default:
        return AppGender.other;
    }
  }

  /// Registered custom user noun grammatical genders
  static final Map<String, AppGender> _customNounGenders = {};

  /// Registers custom grammatical genders (male or female) for domain nouns or brand names.
  ///
  /// Example:
  /// ```dart
  /// AppGender.registerCustomNounGenders({
  ///   'كوفي': AppGender.male,
  ///   'براند': AppGender.male,
  /// });
  /// ```
  static void registerCustomNounGenders(Map<String, AppGender> genders) {
    _customNounGenders.addAll(genders);
  }

  /// Clears all custom user-registered noun genders.
  static void clearCustomNounGenders() {
    _customNounGenders.clear();
  }

  /// Automatically detects the grammatical gender of an Arabic noun or entity.
  ///
  /// In Arabic, grammatical gender applies not only to persons but also to
  /// inanimate objects and entities (المؤنث المجازي واللفظي):
  /// - Words ending in Taa' Marboota (`ة`): e.g. `'شجرة'`, `'صورة'`, `'سيارة'`, `'بطاقة'` -> [AppGender.female]
  /// - Words ending in Alif Maqsoora (`ى`) or Mamdooda (`اء`): e.g. `'ذكرى'`, `'صحراء'` -> [AppGender.female]
  /// - Common semantic feminine nouns without explicit markers: `'شمس'`, `'أرض'`, `'نار'`, `'عين'`, `'يد'`, `'دار'` -> [AppGender.female]
  /// - Words without feminine markers (e.g. `'ملف'`, `'حساب'`, `'تقرير'`, `'رمز'`): -> [AppGender.male]
  ///
  /// For non-Arabic nouns or empty strings, returns [AppGender.other].
  ///
  /// Example:
  /// ```dart
  /// AppGender.detectFromNoun('شجرة'); // AppGender.female
  /// AppGender.detectFromNoun('ملف');   // AppGender.male
  /// ```
  static AppGender detectFromNoun(String? noun) {
    if (noun == null) return AppGender.other;
    final trimmed = noun.trim();
    if (trimmed.isEmpty) return AppGender.other;

    // Check if word contains Arabic letters (exclude pure numbers, Latin text, punctuation)
    final hasArabicLetters = RegExp(r'[\u0621-\u064A]').hasMatch(trimmed);
    if (!hasArabicLetters) {
      return AppGender.other;
    }

    // Remove Arabic definite article ('ال' or 'الـ')
    String word = trimmed;
    if (word.startsWith('الـ')) {
      word = word.substring(3);
    } else if (word.startsWith('ال') && word.length > 2) {
      word = word.substring(2);
    }

    // 0. Check custom user-registered noun genders first (bare word or with article)
    if (_customNounGenders.containsKey(trimmed)) {
      return _customNounGenders[trimmed]!;
    }
    if (_customNounGenders.containsKey(word)) {
      return _customNounGenders[word]!;
    }

    // 1. Male proper names and masculine nouns/plurals ending in 'ة' or 'ات'
    const masculineExceptions = {
      // Male proper names with feminine Taa' Marboota marker
      'حمزة',
      'أسامة',
      'اسامة',
      'طلحة',
      'معاوية',
      'عنترة',
      'عبيدة',
      'قتادة',
      'عكرمة',
      'حذيفة',
      'سلمة',
      'ميسرة',
      // Singular masculine nouns ending in 'ات' (where 'ت' is a root letter)
      'نبات',
      'ثبات',
      'سبات',
      'شتات',
      'فرات',
      'نحات',
      'فتات',
      'رفات',
      // Masculine plurals/proper ending in 'ات'
      'أموات',
      'اموات',
      'عرفات',
    };
    if (masculineExceptions.contains(word)) {
      return AppGender.male;
    }

    // 2. Male human broken plurals ending in 'اء' (أفعلاء / فعلاء لمذكر عاقل)
    const masculinePluralsInAlifMamdooda = {
      'أطباء',
      'اطباء',
      'علماء',
      'وزراء',
      'أمراء',
      'امراء',
      'رؤساء',
      'شعراء',
      'أصدقاء',
      'اصدقاء',
      'فقهاء',
      'خبراء',
      'شهداء',
      'زملاء',
      'وكلاء',
      'أولياء',
      'اولياء',
      'أتقياء',
      'اتقياء',
      'أذكياء',
      'اذكياء',
      'زعماء',
      'خطباء',
    };
    if (masculinePluralsInAlifMamdooda.contains(word)) {
      return AppGender.male;
    }

    // 3. Explicit feminine markers
    // Taa' Marboota (ة) - e.g. شجرة، صورة، بطاقة، رسالة
    if (word.endsWith('ة') || word.endsWith('ـة')) {
      return AppGender.female;
    }

    // Alif Maqsoora (ى) - e.g. ذكرى، كبرى، بشرى
    if (word.endsWith('ى') || word.endsWith('ـى')) {
      return AppGender.female;
    }

    // Non-human plurals ending in 'ات' (قاعدة: كل جمع لغير العاقل مؤنث)
    // e.g. ملفات، حسابات، تطبيقات، سيارات، بيانات، مذكرات
    if (word.endsWith('ات') && word.length > 3) {
      return AppGender.female;
    }

    // Alif Mamdooda (اء) for feminine nouns/adjectives - e.g. صحراء، سماء، خضراء
    if (word.endsWith('اء') && word.length > 3) {
      return AppGender.female;
    }

    // 4. Biological and semantic feminine nouns without explicit markers (المؤنث المعنوي والسماعي)
    const feminineIrregulars = {
      'بنت',
      'أم',
      'ام',
      'أخت',
      'اخت',
      'مرأة',
      'امراة',
      'امرأة',
      'عروس',
      'فتاة',
      'مريم',
      'زينب',
      'هند',
      'سعاد',
      'شمس',
      'أرض',
      'ارض',
      'نار',
      'عين',
      'يد',
      'دار',
      'أذن',
      'اذن',
      'ساق',
      'قدم',
      'ذراع',
      'عصا',
      'جهنم',
      'بئر',
      'كأس',
      'ريح',
      'نفس',
      'فأس',
    };
    if (feminineIrregulars.contains(word)) {
      return AppGender.female;
    }

    // 5. Default for other Arabic nouns: Grammatical Masculine (المذكر المجازي كالملف والحساب)
    return AppGender.male;
  }

  /// Whether this represents the masculine gender.
  bool get isMale => this == AppGender.male;

  /// Whether this represents the feminine gender.
  bool get isFemale => this == AppGender.female;

  /// Whether this represents the neutral/unspecified gender.
  bool get isOther => this == AppGender.other;

  /// Standard normalized key name (`'male'`, `'female'`, `'other'`).
  String get key => name;
}

/// Convenient extension for detecting Arabic grammatical gender from [String].
extension AppGenderNounExtension on String {
  /// Detects the grammatical gender of this Arabic noun.
  ///
  /// Example:
  /// ```dart
  /// 'شجرة'.arabicGender; // AppGender.female
  /// 'ملف'.arabicGender;   // AppGender.male
  /// ```
  AppGender get arabicGender => AppGender.detectFromNoun(this);
}
