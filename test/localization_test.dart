import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

class TestTranslations extends AppTranslations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'hello': 'Hello',
          'welcome': 'Welcome, @name!',
          'items_count': '@count items',
          'greeting': 'Hello friend!',
          'cases_zero': 'No active cases',
          'cases_one': '1 active case',
          'cases_other': '@count active cases',
        },
        'ar': {
          'hello': 'مرحباً',
          'welcome': 'أهلاً بك يا @name!',
          'sentence_punct': 'تطبيق ممتاز!',
          'greeting_male': 'أهلاً بكَ يا صديقي!',
          'greeting_female': 'أهلاً بكِ يا صديقتي!',
          'greeting': 'أهلاً بك يا صديقي!',
          'user_status_m': 'أنت متصل الآن',
          'user_status_f': 'أنتِ متصلة الآن',
          'user_status': 'متصل الآن',
          'cases_zero': 'لا توجد قضايا',
          'cases_one': 'قضية واحدة',
          'cases_two': 'قضيتان',
          'cases_few': '@count قضايا',
          'cases_many': '@count قضية',
          'cases_other': '@count قضية',
        },
        'ar_QA': {
          'firm_city': 'مدينة لوسيل · الدوحة',
        },
      };
}

void main() {
  group('AppForge Localization & BiDi Engine', () {
    setUp(() {
      AppLocalization.instance.init(
        translations: TestTranslations(),
        initialLocale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        userGender: AppGender.other,
      );
    });

    test('AppGender parsing handles standard and Arabic aliases', () {
      expect(AppGender.fromString('male'), AppGender.male);
      expect(AppGender.fromString('M'), AppGender.male);
      expect(AppGender.fromString('masculine'), AppGender.male);
      expect(AppGender.fromString('ذكر'), AppGender.male);
      expect(AppGender.fromString('مذكر'), AppGender.male);

      expect(AppGender.fromString('female'), AppGender.female);
      expect(AppGender.fromString('F'), AppGender.female);
      expect(AppGender.fromString('feminine'), AppGender.female);
      expect(AppGender.fromString('أنثى'), AppGender.female);
      expect(AppGender.fromString('مؤنث'), AppGender.female);

      expect(AppGender.fromString('other'), AppGender.other);
      expect(AppGender.fromString(null), AppGender.other);
      expect(AppGender.fromString('unknown'), AppGender.other);
    });

    test('Detects Arabic grammatical gender from specific test words', () {
      // 1. ملف (مذكر مجازي)
      expect('ملف'.arabicGender, AppGender.male);
      // 2. الملف (مذكر مجازي معرف بال)
      expect('الملف'.arabicGender, AppGender.male);
      // 3. حساب (مذكر مجازي)
      expect('حساب'.arabicGender, AppGender.male);
      // 4. حمزة (علم مذكر حقيقي ذو تأنيث لفظي بالتاء)
      expect('حمزة'.arabicGender, AppGender.male);
      // 5. أطباء (جمع تكسير لمذكر عاقل على وزن أفعلاء)
      expect('أطباء'.arabicGender, AppGender.male);
      // 6. رسالة (مؤنث لفظي بتاء مربوطة)
      expect('رسالة'.arabicGender, AppGender.female);
      // 7. السيارة (مؤنث لفظي معرف بال)
      expect('السيارة'.arabicGender, AppGender.female);
      // 8. ذكرى (مؤنث بألف مقصورة)
      expect('ذكرى'.arabicGender, AppGender.female);
      // 9. صحراء (مؤنث بألف ممدودة)
      expect('صحراء'.arabicGender, AppGender.female);
      // 10. شمس (مؤنث سماعي بدون علامة)
      expect('شمس'.arabicGender, AppGender.female);
      // 11. بنت (مؤنث حقيقي معنوي بالتاء المبسوطة)
      expect('بنت'.arabicGender, AppGender.female);
      // 12. ملفات (جمع لغير العاقل - قاعدة: كل جمع لغير العاقل مؤنث)
      expect('ملفات'.arabicGender, AppGender.female);
      // 13. profile (نص إنجليزي)
      expect('profile'.arabicGender, AppGender.other);
      // 14. 12345 (أرقام بدون حروف عربية)
      expect('12345'.arabicGender, AppGender.other);
    });

    test('Hard Arabic grammatical gender edge cases', () {
      // Group 1: Words ending in 'ت' that are MASCULINE
      expect('نبات'.arabicGender, AppGender.male);
      expect('وقت'.arabicGender, AppGender.male);
      expect('صوت'.arabicGender, AppGender.male);
      expect('بيت'.arabicGender, AppGender.male);
      expect('زيت'.arabicGender, AppGender.male);
      expect('حوت'.arabicGender, AppGender.male);
      expect('موت'.arabicGender, AppGender.male);

      // Group 2: Words ending in 'ت' that are FEMININE
      expect('بنت'.arabicGender, AppGender.female);
      expect('أخت'.arabicGender, AppGender.female);

      // Group 3: Masculine human broken plurals ending in 'اء' (أفعلاء / فعلاء)
      expect('علماء'.arabicGender, AppGender.male);
      expect('وزراء'.arabicGender, AppGender.male);
      expect('أمراء'.arabicGender, AppGender.male);
      expect('شعراء'.arabicGender, AppGender.male);
      expect('رؤساء'.arabicGender, AppGender.male);
      expect('أصدقاء'.arabicGender, AppGender.male);
      expect('خبراء'.arabicGender, AppGender.male);
      expect('شهداء'.arabicGender, AppGender.male);

      // Group 4: Feminine singular nouns/adjectives ending in 'اء'
      expect('سماء'.arabicGender, AppGender.female);
      expect('حسناء'.arabicGender, AppGender.female);
      expect('خضراء'.arabicGender, AppGender.female);

      // Group 5: Masculine proper names ending in 'ة'
      expect('أسامة'.arabicGender, AppGender.male);
      expect('طلحة'.arabicGender, AppGender.male);
      expect('معاوية'.arabicGender, AppGender.male);
      expect('عنترة'.arabicGender, AppGender.male);
      expect('حذيفة'.arabicGender, AppGender.male);

      // Group 6: Non-human plurals ending in 'ات' (feminine agreement)
      expect('حسابات'.arabicGender, AppGender.female);
      expect('بيانات'.arabicGender, AppGender.female);
      expect('تطبيقات'.arabicGender, AppGender.female);
      expect('مستندات'.arabicGender, AppGender.female);
      expect('إشعارات'.arabicGender, AppGender.female);

      // Group 7: Masculine exceptions ending in 'ات'
      expect('أموات'.arabicGender, AppGender.male);
      expect('عرفات'.arabicGender, AppGender.male);

      // Group 8: Paired body parts (feminine) vs single body parts (masculine)
      expect('عين'.arabicGender, AppGender.female);
      expect('يد'.arabicGender, AppGender.female);
      expect('قدم'.arabicGender, AppGender.female);
      expect('ذراع'.arabicGender, AppGender.female);
      expect('أذن'.arabicGender, AppGender.female);
      expect('رأس'.arabicGender, AppGender.male);
      expect('أنف'.arabicGender, AppGender.male);
      expect('قلب'.arabicGender, AppGender.male);

      // Group 9: Nature cosmic elements (feminine vs masculine)
      expect('أرض'.arabicGender, AppGender.female);
      expect('نار'.arabicGender, AppGender.female);
      expect('ريح'.arabicGender, AppGender.female);
      expect('بئر'.arabicGender, AppGender.female);
      expect('دار'.arabicGender, AppGender.female);
      expect('قمر'.arabicGender, AppGender.male);
      expect('بحر'.arabicGender, AppGender.male);
      expect('نجم'.arabicGender, AppGender.male);
      expect('جبل'.arabicGender, AppGender.male);

      // Group 10: Definite article with Tatweel (الـ)
      expect('الـملف'.arabicGender, AppGender.male);
      expect('الـشجرة'.arabicGender, AppGender.female);

      // Group 11: Non-Arabic, symbols, numbers, empty, null
      expect('avatar.png'.arabicGender, AppGender.other);
      expect('١٢٣٤٥'.arabicGender, AppGender.other);
      expect(''.arabicGender, AppGender.other);
      expect('   '.arabicGender, AppGender.other);
      expect(AppGender.detectFromNoun(null), AppGender.other);
    });

    test('Translates keys correctly in active locale', () {
      expect('hello'.tr, 'Hello');
    });

    test('Switches locale dynamically at runtime in memory', () {
      App.setLocale(const Locale('ar', 'QA'));
      expect(App.locale, const Locale('ar', 'QA'));
      expect(App.isRtl, true);
      expect(App.textDirection, TextDirection.rtl);

      // Falls back to 'ar' for keys defined at language level
      expect('hello'.tr, 'مرحباً');
      // Matches specific 'ar_QA' keys
      expect('firm_city'.tr, 'مدينة لوسيل · الدوحة');
    });

    test('Resolves grammatical gender via key suffixes in Arabic', () {
      App.setLocale(const Locale('ar'));

      // Suffix _male
      expect('greeting'.trGender(AppGender.male).contains('أهلاً بكَ يا صديقي'),
          true);

      // Suffix _female
      expect(
          'greeting'.trGender(AppGender.female).contains('أهلاً بكِ يا صديقتي'),
          true);

      // Shorthand _m and _f
      expect('user_status'.trGender(AppGender.male), 'أنت متصل الآن');
      expect('user_status'.trGender(AppGender.female), 'أنتِ متصلة الآن');

      // Fallback to unmarked base key when gender is 'other'
      expect('greeting'.trGender(AppGender.other).contains('أهلاً بك يا صديقي'),
          true);
    });

    test('Honors global App.userGender when no gender argument is passed', () {
      App.setLocale(const Locale('ar'));

      // Set global user profile gender to female
      App.setUserGender(AppGender.female);
      expect(App.userGender, AppGender.female);

      // .trGender() automatically uses App.userGender
      expect('greeting'.trGender().contains('أهلاً بكِ يا صديقتي'), true);

      // .tr also respects global active user gender if gender variant exists
      expect('greeting'.tr.contains('أهلاً بكِ يا صديقتي'), true);

      // Can be overridden locally
      expect('greeting'.trGender(AppGender.male).contains('أهلاً بكَ يا صديقي'),
          true);

      // Reset
      App.setUserGender(AppGender.other);
    });

    test('Resolves inline forms map when provided', () {
      App.setLocale(const Locale('ar'));

      final forms = {
        'male': 'شكراً لكَ يا @name',
        'female': 'شكراً لكِ يا @name',
        'other': 'شكراً لكم',
      };

      expect(
        'thanks'.trGenderForms(forms,
            gender: AppGender.male, params: {'name': 'أحمد'}),
        'شكراً لكَ يا أحمد',
      );
      expect(
        'thanks'.trGenderForms(forms,
            gender: AppGender.female, params: {'name': 'سارة'}),
        'شكراً لكِ يا سارة',
      );
      expect(
        'thanks'.trGender(AppGender.female, {'name': 'سارة'}, forms),
        'شكراً لكِ يا سارة',
      );
      expect(
          'thanks'.trGenderForms(forms, gender: AppGender.other), 'شكراً لكم');
    });

    test('Falls back to fallbackLocale when key is missing in active locale',
        () {
      App.setLocale(const Locale('ar'));
      // 'items_count' only exists in 'en_US'
      expect('items_count'.trParams({'count': '5'}), '5 items');
    });

    test('Returns key string itself if translation is completely missing', () {
      expect('unknown_key'.tr, 'unknown_key');
    });

    test('Interpolates parameters with @key and {key}', () {
      App.setLocale(const Locale('en', 'US'));
      expect('welcome'.trParams({'name': 'Dhia'}), 'Welcome, Dhia!');
    });

    test('Protects phone numbers with Unicode isolates (UAX #9)', () {
      const phone = '+974 5500 1234';
      final safePhone = phone.asPhone;

      // Must start with Left-to-Right Isolate (\u2066) and end with Pop Directional Isolate (\u2069)
      expect(safePhone, '${AppBidi.lri}$phone${AppBidi.pdi}');
      expect(safePhone.startsWith(AppBidi.lri), true);
      expect(safePhone.endsWith(AppBidi.pdi), true);
    });

    test('Sanitizes trailing punctuation in RTL to prevent jumping', () {
      App.setLocale(const Locale('ar'));
      final translated = 'sentence_punct'.tr;
      // Trailing exclamation mark must be guarded by RLM (\u200F)
      expect(translated.endsWith(AppBidi.rlm), true);
    });

    test(
        'Automatically isolates mixed Arabic and Latin tokens without hardcoding',
        () {
      App.setLocale(const Locale('ar'));

      // Mixed Arabic + Latin text
      const rawMixed = 'النمط الحالي: system';
      final isolated = AppBidi.isolateMixed(rawMixed);

      // 'system' must be enclosed in LRI (\u2066) and PDI (\u2069)
      expect(isolated, 'النمط الحالي: ${AppBidi.lri}system${AppBidi.pdi}');

      // .isolateMixed extension produces the same result
      expect(rawMixed.isolateMixed, isolated);

      // .tr automatically applies mixed isolation when in RTL
      final trResult = rawMixed.tr;
      expect(trResult.contains('${AppBidi.lri}system${AppBidi.pdi}'), true);

      // Does not double-wrap if already isolated
      final doubleCheck = AppBidi.isolateMixed(isolated);
      expect(doubleCheck, isolated);
    });

    test(
        'AppBidi.isolateTag and .asTag preserve hashtag symbol (#) on the correct visual side in RTL',
        () {
      // Latin hashtag: must be enclosed in LRI/PDI so '#' stays on the left of 'AppForge'
      expect('#AppForge'.asTag, '${AppBidi.lri}#AppForge${AppBidi.pdi}');
      expect('@username'.asTag, '${AppBidi.lri}@username${AppBidi.pdi}');
      expect(AppBidi.isolateTag('#Flutter'),
          '${AppBidi.lri}#Flutter${AppBidi.pdi}');

      // Arabic hashtag: must be enclosed in RLI/PDI so '#' stays on the right in LTR
      expect('#تطبيق'.asTag, '${AppBidi.rli}#تطبيق${AppBidi.pdi}');

      // In mixed sentences, AppBidi.isolateMixed includes '#' inside the LRI isolate
      const sentence = 'تابعنا على وسم #AppForge الآن';
      final mixedResult = AppBidi.isolateMixed(sentence);
      expect(mixedResult,
          'تابعنا على وسم ${AppBidi.lri}#AppForge${AppBidi.pdi} الآن');
    });

    test(
        '.tr automatically isolates hashtags, handles, and phone numbers in RTL with zero manual tags',
        () {
      App.setLocale(const Locale('ar'));

      // Calling .tr directly on hashtags or phone numbers automatically isolates them in Arabic
      expect('#AppForge'.tr, '${AppBidi.lri}#AppForge${AppBidi.pdi}');
      expect('@AppForge'.tr, '${AppBidi.lri}@AppForge${AppBidi.pdi}');
      expect('+974 5500 1234'.tr, '${AppBidi.lri}+974 5500 1234${AppBidi.pdi}');

      // In English mode, Latin tags and phone numbers remain standard
      App.setLocale(const Locale('en'));
      expect('#AppForge'.tr, '#AppForge');
      expect('+974 5500 1234'.tr, '+974 5500 1234');
    });

    test(
        'AppLocalizationsDelegate provides RTL textDirection for Arabic and LTR for English',
        () async {
      final arLocalizations = await AppLocalizationsDelegate.widgetsDelegate
          .load(const Locale('ar', 'QA'));
      expect(arLocalizations.textDirection, TextDirection.rtl);

      final enLocalizations = await AppLocalizationsDelegate.widgetsDelegate
          .load(const Locale('en', 'US'));
      expect(enLocalizations.textDirection, TextDirection.ltr);
    });

    test('Converts Western digits to Eastern Arabic numerals and vice-versa',
        () {
      expect(123.toArabicDigits, '١٢٣');
      expect('0123456789'.toArabicDigits, '٠١٢٣٤٥٦٧٨٩');
      expect('٠١٢٣٤٥٦٧٨٩'.toWesternDigits, '0123456789');
    });

    test('Evaluates 6-form Arabic pluralization rules accurately', () {
      App.setLocale(const Locale('ar'));

      final forms = {
        'zero': 'لا توجد قضايا',
        'one': 'قضية واحدة',
        'two': 'قضيتان',
        'few': '@count قضايا',
        'many': '@count قضية',
        'other': '@count قضية عامة',
      };

      // 0 -> zero
      expect('cases'.trPlural(0, forms: forms), 'لا توجد قضايا');
      // 1 -> one
      expect('cases'.trPlural(1, forms: forms), 'قضية واحدة');
      // 2 -> two (dual / مثنى)
      expect('cases'.trPlural(2, forms: forms), 'قضيتان');
      // 3 to 10 -> few (جمع قلة)
      expect('cases'.trPlural(3, forms: forms), '3 قضايا');
      expect('cases'.trPlural(10, forms: forms), '10 قضايا');
      // 11 to 99 -> many (تمييز منصوب)
      expect('cases'.trPlural(11, forms: forms), '11 قضية');
      expect('cases'.trPlural(99, forms: forms), '99 قضية');
      // 100+ -> other
      expect('cases'.trPlural(100, forms: forms), '100 قضية عامة');
      expect('cases'.trPlural(102, forms: forms), '102 قضية عامة');
      // Negative numbers: absolute value applies (e.g. -3 -> few)
      expect('cases'.trPlural(-3, forms: forms), '-3 قضايا');
      // Fractional / decimal numbers: CLDR rules map to other
      expect('cases'.trPlural(3.5, forms: forms), '3.5 قضية عامة');
      expect('cases'.trPlural(0.5, forms: forms), '0.5 قضية عامة');
    });

    test(
        'Resolves pluralized keys directly from dictionary without inline forms',
        () {
      App.setLocale(const Locale('ar'));

      // Arabic: 0, 1, 2, 5, 25, 120
      expect('cases'.trPlural(0), 'لا توجد قضايا');
      expect('cases'.trPlural(1), 'قضية واحدة');
      expect('cases'.trPlural(2), 'قضيتان');
      expect('cases'.trPlural(5), '5 قضايا');
      expect('cases'.trPlural(25), '25 قضية');
      expect('cases'.trPlural(120), '120 قضية');

      // With params override for eastern numerals:
      expect('cases'.trPlural(2, params: {'count': '٢'}), 'قضيتان');
      expect('cases'.trPlural(5, params: {'count': '٥'}), '٥ قضايا');

      // English: 0, 1, 5
      App.setLocale(const Locale('en', 'US'));
      expect('cases'.trPlural(0), 'No active cases');
      expect('cases'.trPlural(1), '1 active case');
      expect('cases'.trPlural(5), '5 active cases');
    });

    test('Evaluates English 2-form pluralization accurately', () {
      App.setLocale(const Locale('en', 'US'));

      final forms = {
        'one': '@count file',
        'other': '@count files',
      };

      expect('files'.trPlural(1, forms: forms), '1 file');
      expect('files'.trPlural(0, forms: forms), '0 files');
      expect('files'.trPlural(15, forms: forms), '15 files');
    });

    test('Strips Tashkeel (diacritics) and Tatweel from Arabic text', () {
      expect('مَرْحَباً بِكُمْ'.stripTashkeel, 'مرحبا بكم');
      expect('كِتابُكَ'.stripTashkeel, 'كتابك');
      expect('مــلــف'.stripTatweel, 'ملف');
      expect('السَّلامُ عَلَيْكُمْ'.stripTashkeel, 'السلام عليكم');
    });

    test('Normalizes Arabic text for fuzzy matching and search', () {
      expect('إِلَى مَرْكَزِ التَّطْوِيرِ'.normalizeArabic, 'الي مركز التطوير');
      expect('آفَاقٌ أُخْرَى'.normalizeArabic, 'افاق اخري');

      // Fuzzy contains matches regardless of Tashkeel
      expect('مَرْحَباً بِكَ'.fuzzyContainsArabic('مرحبا'), true);
      expect('تَطْبِيقٌ مُمَيَّزٌ'.fuzzyContainsArabic('تطبيق'), true);
      expect('الملف'.fuzzyContainsArabic('ملف'), true);
    });

    test('Inflects second-person pronouns in Arabic sentences based on gender',
        () {
      const sentence = 'شكراً لكَ يا أحمد، نسعد بتواصلكَ معنا وأنتَ عضو مميز.';

      // Inflect to female
      final femaleVersion = sentence.inflectArabicGender(AppGender.female);
      expect(femaleVersion.contains('لكِ'), true);
      expect(femaleVersion.contains('بتواصلكِ'), true);
      expect(femaleVersion.contains('وأنتِ'), true);
      expect(femaleVersion.contains('عضوة مميزة'), true);

      // Inflect back to male
      final backToMale = femaleVersion.inflectArabicGender(AppGender.male);
      expect(backToMale.contains('لكَ'), true);
      expect(backToMale.contains('بتواصلكَ'), true);
      expect(backToMale.contains('وأنتَ'), true);
      expect(backToMale.contains('عضو مميز'), true);
    });

    test(
        'Falls back to built-in AppCommonTranslations when key is omitted in custom dictionary',
        () {
      // In English
      App.setLocale(const Locale('en', 'US'));
      expect('save'.tr, 'Save');
      expect('cancel'.tr, 'Cancel');
      expect('delete'.tr, 'Delete');
      expect('loading'.tr, 'Loading...');
      expect('retry'.tr, 'Retry');
      expect('settings'.tr, 'Settings');

      // In Arabic
      App.setLocale(const Locale('ar'));
      expect('save'.tr, 'حفظ');
      expect('cancel'.tr, 'إلغاء');
      expect('delete'.tr, 'حذف');
      expect('loading'.tr.startsWith('جارٍ التحميل...'), true);
      expect('retry'.tr, 'إعادة المحاولة');
      expect('settings'.tr, 'الإعدادات');
    });

    test(
        'AppArabicOrthography normalizes Arabic punctuation and spacing correctly',
        () {
      // Punctuation and spacing normalization
      final raw = 'مرحبا , كيف حالك ؟ هل كل شيء بخير ?';
      final normalized = AppArabicOrthography.normalizePunctuation(raw);
      expect(normalized, 'مرحبا، كيف حالك؟ هل كل شيء بخير؟');

      // Parentheses inner space stripping
      final brackets = 'يرجى مراجعة ( التفاصيل ) هنا';
      expect(
        AppArabicOrthography.normalizePunctuation(brackets),
        'يرجى مراجعة (التفاصيل) هنا',
      );
    });

    test('AppArabicOrthography attaches floating Waw al-Atf conjunction', () {
      expect(
        AppArabicOrthography.fixWawConjunction('محمد و أحمد'),
        'محمد وأحمد',
      );
      expect(
        AppArabicOrthography.fixWawConjunction('حفظ و إلغاء'),
        'حفظ وإلغاء',
      );
      expect(
        AppArabicOrthography.fixWawConjunction('نعم و لا'),
        'نعم ولا',
      );
    });

    test(
        'AppArabicOrthography autocorrects common Hamza and Taa Marboota typos',
        () {
      // Hamza + Taa' Marboota in sentence
      const typoSentence = 'يرجى فحص اعدادات الخدمه وارسال الرساله';
      final corrected = AppArabicOrthography.autocorrectWords(typoSentence);
      expect(corrected, 'يرجى فحص إعدادات الخدمة وإرسال الرسالة');

      // Attached proclitics (ب، و، ل، ال)
      expect(
        AppArabicOrthography.autocorrectWords('بالخدمه'),
        'بالخدمة',
      );
      expect(
        AppArabicOrthography.autocorrectWords('والاعدادات'),
        'والإعدادات',
      );

      // Hamzat Wasl corrections (removing wrongful hamza)
      expect(
        AppArabicOrthography.autocorrectWords('إستخدام النظام'),
        'استخدام النظام',
      );

      // Taa Marboota vs Haa on pronouns
      expect(
        AppArabicOrthography.autocorrectWords('النظر فية'),
        'النظر فيه',
      );

      // Alif Maqsoora
      expect(
        AppArabicOrthography.autocorrectWords('الي اللقاء'),
        'إلى اللقاء',
      );
    });

    test(
        'All-in-one .formatArabic() pipeline combines all pro-grade corrections',
        () {
      const input = 'مرحبا , يرجى فتح اعدادات الخدمه و ارسال الرساله ?';
      final formatted = input.formatArabic();
      expect(
        formatted,
        'مرحباً، يرجى فتح إعدادات الخدمة وإرسال الرسالة؟',
      );
    });

    test(
        'QWERTY to Arabic layout mistyping converter maps keystrokes accurately',
        () {
      expect('lvpfh'.toArabicKeyboard(), 'مرحبا');
      expect('HighW'.toArabicKeyboard(), 'أهلاً');
      expect(
        AppArabicOrthography.isProbablyMistypedQwerty('lvpfh'),
        true,
      );
      expect(
        AppArabicOrthography.isProbablyMistypedQwerty('مرحبا'),
        false,
      );
    });

    test('ArabicTextInputFormatter formats input in real time', () {
      const formatter = ArabicTextInputFormatter(
        fixWawSpacing: true,
        fixPunctuation: true,
        autoCorrectCommonWords: true,
      );

      // Simulate typing 'و احمد'
      const oldVal = TextEditingValue(text: 'و ');
      const newVal = TextEditingValue(
        text: 'و احمد',
        selection: TextSelection.collapsed(offset: 7),
      );

      final updated = formatter.formatEditUpdate(oldVal, newVal);
      expect(updated.text, 'وأحمد');
    });

    test('AppLocalization.isLiteralToken identifies non-translatable tokens',
        () {
      expect(AppLocalization.isLiteralToken('#AppForge'), true);
      expect(AppLocalization.isLiteralToken('#flutter_dev'), true);
      expect(AppLocalization.isLiteralToken('@dhia'), true);
      expect(AppLocalization.isLiteralToken('+974 5500 1234'), true);
      expect(AppLocalization.isLiteralToken('+1-800-555-0199'), true);
      expect(AppLocalization.isLiteralToken('https://flutter.dev'), true);
      expect(AppLocalization.isLiteralToken('http://example.com'), true);
      expect(
          AppLocalization.isLiteralToken('mailto:support@appforge.dev'), true);
      expect(AppLocalization.isLiteralToken('user@domain.com'), true);

      // Translatable keys must return false
      expect(AppLocalization.isLiteralToken('hello'), false);
      expect(AppLocalization.isLiteralToken('settings_title'), false);
      expect(AppLocalization.isLiteralToken('cases_zero'), false);
    });

    test('Literal tokens bypass missingKeys and onMissingKey tracking in .tr',
        () {
      final missingNotified = <String>[];
      AppLocalization.instance.clearMissingKeys();
      AppLocalization.instance.onMissingKey = (key, locale) {
        missingNotified.add(key);
      };

      // Calling .tr on a literal phone number or hashtag should sanitize but NOT flag as missing key
      final phone = '+974 5500 1234'.tr;
      expect(phone.contains('+974 5500 1234'), true);

      final tag = '#AppForge'.tr;
      expect(tag.contains('#AppForge'), true);

      final url = 'https://flutter.dev'.tr;
      expect(url.contains('https://flutter.dev'), true);

      // Neither should be in missingKeys or have invoked onMissingKey
      expect(AppLocalization.instance.missingKeys.contains('+974 5500 1234'),
          false);
      expect(AppLocalization.instance.missingKeys.contains('#AppForge'), false);
      expect(
          AppLocalization.instance.missingKeys.contains('https://flutter.dev'),
          false);
      expect(missingNotified.isEmpty, true);

      // But a genuinely missing dictionary key DOES trigger tracking
      final genuinelyMissing = 'untranslated_feature_flag'.tr;
      expect(genuinelyMissing, 'untranslated_feature_flag');
      expect(
          AppLocalization.instance.missingKeys
              .contains('untranslated_feature_flag'),
          true);
      expect(missingNotified.contains('untranslated_feature_flag'), true);

      AppLocalization.instance.onMissingKey = null;
    });

    test(
        'Static translation caching delivers memoized lookups and invalidates cleanly',
        () {
      AppLocalization.instance.setLocale(const Locale('en', 'US'));

      // First lookup populates static cache
      final val1 = 'hello'.tr;
      expect(val1, 'Hello');

      // Subsequent lookup should match
      final val2 = 'hello'.tr;
      expect(identical(val1, val2) || val1 == val2, true);

      // Changing locale invalidates static cache and yields new locale translation
      AppLocalization.instance.setLocale(const Locale('ar'));
      expect('hello'.tr, 'مرحباً');

      // Reset to en_US
      AppLocalization.instance.setLocale(const Locale('en', 'US'));
      expect('hello'.tr, 'Hello');
    });

    test('setTranslations and invalidateCache update snapshot immediately', () {
      final customTrans = AppTranslations.fromMap({
        'en_US': {'dynamic_key': 'Original Value'},
      });
      AppLocalization.instance.setTranslations(customTrans);
      expect('dynamic_key'.tr, 'Original Value');

      final updatedTrans = AppTranslations.fromMap({
        'en_US': {'dynamic_key': 'Updated Value'},
      });
      AppLocalization.instance.setTranslations(updatedTrans);
      expect('dynamic_key'.tr, 'Updated Value');

      // Re-init with default test translations for test safety
      AppLocalization.instance.init(
        translations: TestTranslations(),
        initialLocale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
      );
    });
  });
}
