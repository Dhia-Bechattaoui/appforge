import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

class LocalizationTab extends StatefulWidget {
  const LocalizationTab({super.key});

  @override
  State<LocalizationTab> createState() => _LocalizationTabState();
}

class _LocalizationTabState extends State<LocalizationTab> {
  int _counter = 2; // Starts at 2 to highlight Arabic dual (المثنى)
  final String _testPhone = '+974 5500 1234';

  // Arabic Tashkeel & Gender Showcase States
  AppAuditReport? _auditReport;
  String _selectedNoun = 'حمزة';
  AppGender _pronounGender = AppGender.female;
  static const String _sampleTashkeel =
      'شُكْرًا لَكَ يَا مُسْتَخْدِمَ التَّطْبِيقِ';
  static const String _sampleTatweel = 'آبــــفــــورج';
  static const String _sampleSentence =
      'شكراً لكَ يا صديقي، هل هذا ملفكَ؟ وأنتَ عضو مميز.';
  static const List<String> _testNouns = [
    'ملف',
    'رسالة',
    'حساب',
    'حمزة',
    'أطباء',
    'شمس',
    'بنت',
    'السيارة',
    'ذكرى',
    'صحراء',
    'ملفات',
  ];

  late final TextEditingController _orthoInputController =
      TextEditingController(
        text: 'مرحبا , يرجى فتح اعدادات الخدمه و ارسال الرساله ?',
      );

  @override
  void dispose() {
    _orthoInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = App.isRtl;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    final pluralResolvedText = 'cases'.trPlural(
      _counter,
      params: {'count': _counter.toString().toArabicDigits},
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Phone number direction protection (UAX #9)
        _buildCard(
          title: 'phone_title'.tr,
          description: 'phone_desc'.tr,
          child: Column(
            children: [
              _buildComparisonRow(
                label: 'phone_with_appforge'.tr,
                value: _testPhone.asPhone,
                isHighlighted: true,
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                label: 'phone_without_appforge'.tr,
                value: _testPhone,
                isHighlighted: false,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2. 6-case Arabic plurals
        _buildCard(
          title: 'plurals_title'.tr,
          description: 'plurals_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.15 : 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.35 : 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'current_count_label'.trParams({
                        'count': isArabic
                            ? '${_counter.toString().toArabicDigits} ($_counter)'
                            : '$_counter',
                      }),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pluralResolvedText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Stepper controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildCounterButton(
                    icon: Icons.remove,
                    onPressed: () {
                      if (_counter > 0) setState(() => _counter--);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      isArabic
                          ? _counter.toString().toArabicDigits
                          : '$_counter',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : primary,
                      ),
                    ),
                  ),
                  _buildCounterButton(
                    icon: Icons.add,
                    onPressed: () => setState(() => _counter++),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Quick-select chips wrapped dynamically to avoid horizontal overflow
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final val in [0, 1, 2, 5, 25, 120])
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        isArabic ? val.toString().toArabicDigits : '$val',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _counter == val
                              ? onPrimary
                              : (isDark ? const Color(0xFFF1F5F9) : primary),
                        ),
                      ),
                      backgroundColor: _counter == val
                          ? primary
                          : (isDark
                                ? theme.cardColor
                                : const Color(0xFFF1F5F9)),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade300,
                        width: 0.8,
                      ),
                      onPressed: () => setState(() => _counter = val),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Mixed Script & Punctuation
        _buildCard(
          title: 'mixed_title'.tr,
          description: 'mixed_desc'.tr,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.scaffoldBackgroundColor
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
              ),
            ),
            child: Text(
              'mixed_sample'.tr,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFF1F5F9) : primary,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 4. Numerals Conversion
        _buildCard(
          title: 'digits_title'.tr,
          description: 'digits_desc'.tr,
          child: Column(
            children: [
              _buildComparisonRow(
                label: 'Western Digits:',
                value: '2026-10-21',
                isHighlighted: false,
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                label: 'Eastern Digits (.toArabicDigits):',
                value: '2026-10-21'.toArabicDigits,
                isHighlighted: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 5. Grammatical Gender Engine (التذكير والتأنيث)
        ValueListenableBuilder<AppGender>(
          valueListenable: App.genderNotifier,
          builder: (context, activeGender, _) {
            final testName = isArabic
                ? (activeGender == AppGender.female ? 'سارة' : 'أحمد')
                : (activeGender == AppGender.female ? 'Sarah' : 'Ahmed');

            return _buildCard(
              title: 'gender_title'.tr,
              description: 'gender_desc'.tr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'gender_morph_hint'.tr,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildGenderChip(
                        gender: AppGender.male,
                        label: 'gender_male'.tr,
                        icon: Icons.male,
                        isSelected: activeGender == AppGender.male,
                        onSelected: () => App.setUserGender(AppGender.male),
                      ),
                      _buildGenderChip(
                        gender: AppGender.female,
                        label: 'gender_female'.tr,
                        icon: Icons.female,
                        isSelected: activeGender == AppGender.female,
                        onSelected: () => App.setUserGender(AppGender.female),
                      ),
                      _buildGenderChip(
                        gender: AppGender.other,
                        label: 'gender_other'.tr,
                        icon: Icons.person_outline,
                        isSelected: activeGender == AppGender.other,
                        onSelected: () => App.setUserGender(AppGender.other),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildComparisonRow(
                    label: 'user_greeting_label'.tr,
                    value: 'user_greeting'.trGender(null, {'name': testName}),
                    isHighlighted: true,
                  ),
                  const SizedBox(height: 8),
                  _buildComparisonRow(
                    label: 'user_status_label'.tr,
                    value: 'user_status'.trGender(),
                    isHighlighted: false,
                  ),
                  const SizedBox(height: 8),
                  _buildComparisonRow(
                    label: 'action_confirm_label'.tr,
                    value: 'action_confirm'.trGender(),
                    isHighlighted: false,
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // 6. Arabic Tashkeel & Diacritics Engine
        _buildCard(
          title: 'tashkeel_title'.tr,
          description: 'tashkeel_desc'.tr,
          child: Column(
            children: [
              _buildComparisonRow(
                label: 'tashkeel_original'.tr,
                value: _sampleTashkeel,
                isHighlighted: false,
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                label: 'tashkeel_stripped'.tr,
                value: _sampleTashkeel.stripTashkeel,
                isHighlighted: true,
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                label: 'tatweel_stripped'.tr,
                value: '$_sampleTatweel -> ${_sampleTatweel.stripTatweel}',
                isHighlighted: false,
              ),
              const SizedBox(height: 8),
              _buildComparisonRow(
                label: 'tashkeel_search_test'.trParams({'query': 'ملف'}),
                value: 'مَلَفّ'.fuzzyContainsArabic('ملف')
                    ? 'search_matched'.tr
                    : 'search_not_matched'.tr,
                isHighlighted: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 7. Dynamic Pronoun & Suffix Harakat (كَ / كِ)
        _buildCard(
          title: 'inflect_title'.tr,
          description: 'inflect_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'pronoun_morph_hint'.tr,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildGenderChip(
                    gender: AppGender.male,
                    label: 'pronoun_male'.tr,
                    icon: Icons.male,
                    isSelected: _pronounGender == AppGender.male,
                    onSelected: () =>
                        setState(() => _pronounGender = AppGender.male),
                  ),
                  _buildGenderChip(
                    gender: AppGender.female,
                    label: 'pronoun_female'.tr,
                    icon: Icons.female,
                    isSelected: _pronounGender == AppGender.female,
                    onSelected: () =>
                        setState(() => _pronounGender = AppGender.female),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFC99A3D).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFC99A3D).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _sampleSentence.inflectArabicGender(_pronounGender),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : primary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 8. Noun Grammatical Gender Detector
        _buildCard(
          title: 'noun_detector_title'.tr,
          description: 'noun_detector_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'noun_detector_tap'.tr,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final noun in _testNouns)
                    ChoiceChip(
                      label: Text(
                        noun,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedNoun == noun
                              ? onPrimary
                              : (isDark ? const Color(0xFFF1F5F9) : primary),
                        ),
                      ),
                      selected: _selectedNoun == noun,
                      selectedColor: primary,
                      backgroundColor: isDark
                          ? theme.cardColor
                          : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade300,
                        width: 0.8,
                      ),
                      onSelected: (_) => setState(() => _selectedNoun = noun),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final detected = _selectedNoun.arabicGender;
                  final isFemale = detected == AppGender.female;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isFemale
                          ? Colors.purple.withValues(alpha: 0.08)
                          : Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isFemale
                            ? Colors.purple.withValues(alpha: 0.3)
                            : Colors.blue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'noun_detected_gender'.trParams({
                            'noun': _selectedNoun,
                          }),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isFemale
                                ? (isDark
                                      ? Colors.purple.shade200
                                      : Colors.purple.shade900)
                                : (isDark
                                      ? const Color(0xFF7DD3FC)
                                      : Colors.blue.shade900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isFemale ? Colors.purple : primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isFemale
                                ? 'noun_gender_female'.tr
                                : 'noun_gender_male'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 9. Built-in Universal Dictionary
        _buildCard(
          title: 'common_tr_title'.tr,
          description: 'common_tr_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCommonChip('save', Icons.save),
                  _buildCommonChip('cancel', Icons.close),
                  _buildCommonChip('delete', Icons.delete_outline),
                  _buildCommonChip('retry', Icons.refresh),
                  _buildCommonChip('settings', Icons.settings),
                  _buildCommonChip('loading', Icons.hourglass_empty),
                  _buildCommonChip('back', Icons.arrow_back),
                  _buildCommonChip('confirm', Icons.check),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 10. Pro-Grade Arabic Orthography & Keyboard Engine
        _buildCard(
          title: 'orthography_title'.tr,
          description: 'orthography_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ortho_input_field_label'.tr,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _orthoInputController,
                inputFormatters: const [
                  ArabicTextInputFormatter(
                    fixWawSpacing: true,
                    fixPunctuation: true,
                    autoCorrectCommonWords: true,
                  ),
                ],
                decoration: InputDecoration(hintText: 'input_hint_ortho'.tr),
              ),
              const SizedBox(height: 12),
              Text(
                'ortho_sample_presets_label'.tr,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'ortho_sample_waw'.tr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _orthoInputController.text = 'محمد و أحمد';
                    },
                  ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'ortho_sample_common'.tr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _orthoInputController.text = 'فتح اعدادات الخدمه';
                    },
                  ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'ortho_sample_qwerty'.tr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _orthoInputController.text = 'lvpfh'.toArabicKeyboard();
                    },
                  ),
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'ortho_sample_punctuation'.tr,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () {
                      _orthoInputController.text =
                          'مرحبا , كيف حالك ? ( تفاصيل )'.formatArabic();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 11. Translation Cleaner & Resource Auditor
        _buildCard(
          title: 'cleaner_title'.tr,
          description: 'cleaner_desc'.tr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.analytics_outlined, size: 18),
                      label: Text(
                        'btn_run_audit'.tr,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        setState(() {
                          _auditReport = App.auditTranslations();
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_auditReport != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _auditReport!.isClean
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _auditReport!.isClean
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFFCA5A5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _auditReport!.isClean
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                            color: _auditReport!.isClean
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFDC2626),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _auditReport!.isClean
                                  ? 'audit_clean_msg'.tr
                                  : 'Found ${_auditReport!.totalIssues} issue(s) across locales',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _auditReport!.isClean
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'audit_stats'.trParams({
                          'locales': '${_auditReport!.totalLocales}',
                          'keys': '${_auditReport!.totalKeysDefined}',
                        }),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          height: 1.5,
                        ),
                      ),
                      if (_auditReport!.unregisteredKeys.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '• Missing keys in code: ${_auditReport!.unregisteredKeys.join(", ")}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.scaffoldBackgroundColor
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.terminal,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'cli_clean_hint'.tr,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF334155),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFF8FAFC)
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String value,
    required bool isHighlighted,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted
            ? const Color(0xFFC99A3D).withValues(alpha: isDark ? 0.2 : 0.12)
            : (isDark ? theme.cardColor : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? const Color(0xFFC99A3D).withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF334155) : Colors.transparent),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isHighlighted
                    ? (isDark
                          ? const Color(0xFFFCD34D)
                          : const Color(0xFF8B641B))
                    : (isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF475569)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isHighlighted
                    ? (isDark
                          ? const Color(0xFFFCD34D)
                          : theme.colorScheme.primary)
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return Material(
      color: primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: onPrimary, size: 16),
        ),
      ),
    );
  }

  Widget _buildGenderChip({
    required AppGender gender,
    required String label,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onSelected,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? onPrimary
            : (isDark ? const Color(0xFFE2E8F0) : primary),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isSelected
              ? onPrimary
              : (isDark ? const Color(0xFFE2E8F0) : primary),
        ),
      ),
      selectedColor: primary,
      backgroundColor: isDark ? theme.cardColor : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
        width: 0.8,
      ),
      onSelected: (_) {
        if (onSelected != null) {
          onSelected();
        } else {
          App.setUserGender(gender);
        }
      },
    );
  }

  Widget _buildCommonChip(String key, IconData icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Chip(
      avatar: Icon(
        icon,
        size: 15,
        color: isDark ? const Color(0xFF94A3B8) : primary,
      ),
      label: Text(
        key.tr,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE2E8F0) : primary,
        ),
      ),
      backgroundColor: isDark ? theme.cardColor : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isDark
            ? const Color(0xFF334155)
            : Colors.grey.withValues(alpha: 0.3),
        width: 0.8,
      ),
    );
  }
}
