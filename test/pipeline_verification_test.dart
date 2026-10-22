import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  test(
      'End-to-End Pro Arabic Transformation: Gender + Formatting + Autocorrect',
      () {
    const rawInput =
        'مرحبا , شكراً لكَ يا صديقنا ، يرجى فتح اعدادات الخدمه و فحص ( ملفكَ ) و ارسال الرساله للتاكيد ?';

    // 1. Inflect gender to female
    final femaleInflected = rawInput.inflectArabicGender(AppGender.female);

    // 2. Format Arabic (Waw attachment + autocorrect + punctuation & brackets)
    final perfectlyFormatted = femaleInflected.formatArabic();

    // ignore: avoid_print
    print('RAW INPUT:');
    // ignore: avoid_print
    print(rawInput);
    // ignore: avoid_print
    print('\nOUTPUT PERFECT ARABIC (FEMALE):');
    // ignore: avoid_print
    print(perfectlyFormatted);

    // Assertions:
    // Punctuation & Brackets
    expect(perfectlyFormatted.contains('مرحباً،'), true);
    expect(perfectlyFormatted.contains('صديقتنا،'), true);
    expect(perfectlyFormatted.contains('(ملفكِ)'), true);
    expect(perfectlyFormatted.endsWith('؟'), true);

    // Conjunction Waw al-'Atf attached
    expect(perfectlyFormatted.contains('وفحص'), true);
    expect(perfectlyFormatted.contains('وإرسال'), true);

    // Autocorrect
    expect(perfectlyFormatted.contains('إعدادات'), true);
    expect(perfectlyFormatted.contains('الخدمة'), true);
    expect(perfectlyFormatted.contains('الرسالة'), true);
    expect(perfectlyFormatted.contains('للتأكيد؟'), true);

    // Female gender inflection
    expect(perfectlyFormatted.contains('لكِ'), true);
    expect(perfectlyFormatted.contains('صديقتنا'), true);
    expect(perfectlyFormatted.contains('ملفكِ'), true);
  });

  test(
      'Authentic Arabic gender inflection on relational vocatives & predicates',
      () {
    // 1. Starting from standard male form:
    const maleSentence = 'شكراً لكَ يا صديقي، هل هذا ملفكَ؟ وأنتَ عضو مميز.';
    final femaleResult = maleSentence.inflectArabicGender(AppGender.female);
    expect(
        femaleResult, 'شكراً لكِ يا صديقتي، هل هذا ملفكِ؟ وأنتِ عضوة مميزة.');

    // 2. Inflecting back to male:
    final backToMale = femaleResult.inflectArabicGender(AppGender.male);
    expect(backToMale, 'شكراً لكَ يا صديقي، هل هذا ملفكَ؟ وأنتَ عضو مميز.');

    // 3. User's exact partially-inflected input:
    const partialInput = 'شكراً لكِ يا صديقي، هل هذا ملفكِ؟ وأنتِ عضو مميز.';
    final fullFemaleResult = partialInput.inflectArabicGender(AppGender.female);
    expect(fullFemaleResult,
        'شكراً لكِ يا صديقتي، هل هذا ملفكِ؟ وأنتِ عضوة مميزة.');

    // 4. All-in-one formatArabic with gender parameter:
    const rawParagraph = 'مرحبا , شكراً لكَ يا صديقي و تاكد من فحص ( ملفكَ ) ?';
    final allInOne = rawParagraph.formatArabic(gender: AppGender.female);
    expect(allInOne, 'مرحباً، شكراً لكِ يا صديقتي وتأكدي من فحص (ملفكِ)؟');
  });

  test(
      'Developer can feed custom dictionaries for autocorrect, gender pairs & noun gender',
      () {
    // 1. Global autocorrect dictionary feeding
    App.registerArabicWords({
      'ضياء': 'ضِياء',
      'حميدان': 'حُميدان',
      'ستارتب': 'ستارت آب',
    });

    const customText = 'مرحبا يا حميدان ، وبالضياء نلتقي في ستارتب مميز .';
    final correctedText = customText.formatArabic();
    expect(
        correctedText, 'مرحباً يا حُميدان، وبالضِياء نلتقي في ستارت آب مميز.');

    // 2. Global gender inflection pairs feeding
    App.registerArabicGenderPairs([
      ['كابتن', 'كابتنة'],
      ['طبيبنا', 'طبيبتنا'],
      ['مهندس أول', 'مهندسة أولى'],
    ]);

    const teamMsg = 'شكراً لكَ يا كابتن ، وأنتَ مهندس أول وطبيبنا الرائع .';
    final femaleTeamMsg = teamMsg.formatArabic(gender: AppGender.female);
    expect(femaleTeamMsg,
        'شكراً لكِ يا كابتنة، وأنتِ مهندسة أولى وطبيبتنا الرائعة.');

    // 3. Global custom noun grammatical gender
    App.registerArabicNounGenders({
      'كوفي': AppGender.male,
      'براند': AppGender.male,
    });
    expect('كوفي'.arabicGender, AppGender.male);
    expect('براند'.arabicGender, AppGender.male);

    // 4. Per-call inline custom dictionary and pairs override
    const localText = 'أهلاً يا فيصل ويا كوتش ، تفضل بالدخول .';
    final localResult = localText.formatArabic(
      gender: AppGender.female,
      customDictionary: {'فيصل': 'فَيْصَل'},
      customGenderPairs: [
        ['كوتش', 'كوتشة'],
      ],
    );
    expect(localResult, 'أهلاً يا فَيْصَل ويا كوتشة، تفضلي بالدخول.');

    // Cleanup
    App.clearArabicWords();
    App.clearArabicGenderPairs();
    App.clearArabicNounGenders();
  });
}
