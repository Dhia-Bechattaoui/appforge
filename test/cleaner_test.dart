import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

class SampleAuditedTranslations extends AppTranslations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': {
          'title': 'My Application',
          'welcome': 'Welcome @name',
          'only_in_en': 'English only string',
          'empty_val': '   ',
          'cases_zero': 'No cases',
          'cases_other': '@count cases',
          'user_status_male': 'Active male',
          'dead_key_1': 'Never used anywhere',
        },
        'ar_QA': {
          'title': 'تطبيقي',
          'welcome': 'أهلاً يا @name',
          'only_in_ar': 'نص عربي فقط',
          'cases_zero': 'لا توجد قضايا',
          'cases_other': '@count قضية',
          'user_status_female': 'نشطة',
          'dead_key_2': 'مفتاح مهمل',
        },
      };
}

void main() {
  group('Step 7: Resource Cleaner & Translation Auditor', () {
    test(
        'AppTranslationAuditor.auditDictionary detects cross-locale gaps and empty strings',
        () {
      final report =
          AppTranslationAuditor.auditDictionary(SampleAuditedTranslations());

      expect(report.isClean, false);
      expect(report.totalLocales, 2);
      expect(report.totalKeysDefined, 11);

      // ar_QA is missing 'only_in_en' and 'empty_val' and 'user_status_male' and 'dead_key_1'
      expect(report.missingKeys['ar_QA']!.contains('only_in_en'), true);
      expect(report.missingKeys['ar_QA']!.contains('empty_val'), true);
      expect(report.missingKeys['ar_QA']!.contains('dead_key_1'), true);

      // en_US is missing 'only_in_ar' and 'user_status_female' and 'dead_key_2'
      expect(report.missingKeys['en_US']!.contains('only_in_ar'), true);
      expect(report.missingKeys['en_US']!.contains('dead_key_2'), true);

      // Empty / whitespace keys
      expect(report.emptyKeys['en_US']!.contains('empty_val'), true);
      expect(report.emptyKeys.containsKey('ar_QA'), false);
    });

    test('auditDictionary throws ArgumentError when passed invalid type', () {
      expect(
        () => AppTranslationAuditor.auditDictionary(12345),
        throwsA(isA<ArgumentError>()),
      );
    });

    test(
        'extractKeysFromSource captures all variants of .tr extensions accurately',
        () {
      const sampleDartCode = '''
        final a = 'hello_world'.tr;
        final b = "user_name".trParams({'name': 'Sara'});
        final c = 'active_cases'.trPlural(quantity);
        final d = 'greeting_msg'.trGender(AppGender.female);
        final e = 'custom_forms'.trGenderForms({'male': 'X'});
        final untranslated = 'plain string without tr';
      ''';

      final extracted =
          AppTranslationAuditor.extractKeysFromSource(sampleDartCode);

      expect(extracted.contains('hello_world'), true);
      expect(extracted.contains('user_name'), true);
      expect(extracted.contains('active_cases'), true);
      expect(extracted.contains('greeting_msg'), true);
      expect(extracted.contains('custom_forms'), true);
      expect(extracted.contains('plain string without tr'), false);
      expect(extracted.length, 5);
    });

    test(
        'scanProject accurately reports dead keys, unregistered keys, and suffix variants',
        () {
      // Create a temporary project directory for testing static scanning
      final tempDir =
          Directory.systemTemp.createTempSync('appforge_cleaner_test_');

      try {
        final sampleSourceFile = File('${tempDir.path}/main.dart');
        sampleSourceFile.writeAsStringSync('''
          import 'package:appforge/appforge.dart';

          void render() {
            print('title'.tr);
            print('welcome'.trParams({'name': 'Ali'}));
            print('cases'.trPlural(5)); // matches cases_zero / cases_other base key
            print('user_status'.trGender()); // matches user_status_male / user_status_female
            print('unregistered_code_key'.tr); // not in dictionary
            print('save'.tr); // universal common key (should not be flagged as unregistered)
          }
        ''');

        final report = AppTranslationAuditor.scanProject(
          rootDir: tempDir,
          translations: SampleAuditedTranslations(),
        );

        // 'dead_key_1' and 'dead_key_2' must be flagged as unused
        expect(report.unusedKeys.contains('dead_key_1'), true);
        expect(report.unusedKeys.contains('dead_key_2'), true);

        // 'cases_zero' and 'user_status_male' should NOT be unused because their base was used
        expect(report.unusedKeys.contains('cases_zero'), false);
        expect(report.unusedKeys.contains('user_status_male'), false);

        // 'unregistered_code_key' must be flagged as unregistered
        expect(report.unregisteredKeys.contains('unregistered_code_key'), true);

        // 'save' is a universal built-in key and must not be flagged as unregistered
        expect(report.unregisteredKeys.contains('save'), false);

        // Summary format test
        final summary = report.summary;
        expect(summary.contains('AppForge Translation Audit Report'), true);
        expect(
            summary.contains('Dead / Unused Keys Defined in Dictionary'), true);
        expect(summary.contains('Unregistered Keys Used in Code'), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('App.auditTranslations facade method integrates seamlessly', () {
      // Initialize with test translations
      AppLocalization.instance.init(translations: SampleAuditedTranslations());

      final report = App.auditTranslations();
      expect(report.totalLocales, 2);
      expect(report.totalKeysDefined, 11);
      expect(report.missingKeys['ar_QA']!.contains('only_in_en'), true);

      // JSON serialization
      final json = report.toJson();
      expect(json['isClean'], false);
      expect(json['totalIssues'], greaterThan(0));
      expect(json['totalKeysDefined'], 11);
      expect(json['totalLocales'], 2);
    });

    test('A synchronized dictionary produces an isClean = true report', () {
      final cleanDict = {
        'en': {'a': 'Apple', 'b': 'Banana'},
        'ar': {'a': 'تفاحة', 'b': 'موزة'},
      };

      final report = AppTranslationAuditor.auditDictionary(cleanDict);
      expect(report.isClean, true);
      expect(report.totalIssues, 0);
      expect(report.summary.contains('100% synchronized and free of dead keys'),
          true);
    });

    test('findTranslationFiles and pruneUnusedKeys clean dead keys with backup',
        () {
      final tempDir =
          Directory.systemTemp.createTempSync('appforge_prune_test_');

      try {
        final dartFile = File('${tempDir.path}/messages.dart');
        dartFile.writeAsStringSync('''
import 'package:appforge/appforge.dart';

class MyTrans extends AppTranslations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'keep_me': 'Active key',
      'prune_me': 'Dead key to delete',
      'multiline': \'\'\'
        text line 1
        text line 2
      \'\'\',
    },
    'ar': {
      'keep_me': 'مفتاح نشط',
      'prune_me': 'مفتاح مهمل للحذف',
    },
  };
}
''');

        // 1. Discover file
        final discovered = AppTranslationAuditor.findTranslationFiles(tempDir);
        expect(discovered.length, 1);
        expect(discovered.first.allKeys.contains('keep_me'), true);
        expect(discovered.first.allKeys.contains('prune_me'), true);
        expect(discovered.first.keyLineNumbers['prune_me'], greaterThan(0));

        // 2. Prune unused key
        final removedCount = AppTranslationAuditor.pruneUnusedKeys(
          file: dartFile,
          unusedKeys: ['prune_me'],
          createBackup: true,
        );

        expect(removedCount, 2); // Once in 'en', once in 'ar'

        // Verify backup exists
        final backupFile = File('${dartFile.path}.bak');
        expect(backupFile.existsSync(), true);
        expect(backupFile.readAsStringSync().contains('prune_me'), true);

        // Verify cleaned file
        final cleanedContent = dartFile.readAsStringSync();
        expect(cleanedContent.contains('prune_me'), false);
        expect(cleanedContent.contains('keep_me'), true);
        expect(cleanedContent.contains('text line 2'), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('pruneUnusedKeys safely prunes JSON and ARB files', () {
      final tempDir =
          Directory.systemTemp.createTempSync('appforge_json_test_');

      try {
        final jsonFile = File('${tempDir.path}/en.json');
        jsonFile.writeAsStringSync('''{
  "active_key": "Keep this",
  "dead_key": "Remove this"
}''');

        final removedCount = AppTranslationAuditor.pruneUnusedKeys(
          file: jsonFile,
          unusedKeys: ['dead_key'],
          createBackup: false,
        );

        expect(removedCount, 1);
        final cleaned = jsonFile.readAsStringSync();
        expect(cleaned.contains('dead_key'), false);
        expect(cleaned.contains('active_key'), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('AppAssetAuditor detects unreferenced assets and prunes with backup',
        () {
      final tempDir =
          Directory.systemTemp.createTempSync('appforge_asset_test_');

      try {
        final assetsDir = Directory('${tempDir.path}/assets/images')
          ..createSync(recursive: true);
        final libDir = Directory('${tempDir.path}/lib')
          ..createSync(recursive: true);

        final usedAsset = File('${assetsDir.path}/logo.png')
          ..writeAsStringSync('logo_binary');
        final unusedAsset = File('${assetsDir.path}/old_banner.png')
          ..writeAsStringSync('banner_binary');

        final codeFile = File('${libDir.path}/main.dart');
        codeFile.writeAsStringSync('''
          import 'package:flutter/material.dart';
          Widget build() => Image.asset('assets/images/logo.png');
        ''');

        // Scan for unused assets
        final unused = AppAssetAuditor.findUnusedAssets(tempDir);
        expect(unused.length, 1);
        expect(unused.first.path.endsWith('old_banner.png'), true);

        // Prune unused asset
        final prunedCount = AppAssetAuditor.pruneUnusedAssets(
          unused,
          projectDir: tempDir,
          createBackup: true,
        );

        expect(prunedCount, 1);
        expect(unusedAsset.existsSync(), false);
        expect(usedAsset.existsSync(), true);

        // Verify moved to trash
        final trashFile =
            File('${tempDir.path}/.appforge_trash/assets/old_banner.png');
        expect(trashFile.existsSync(), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('AppFileAuditor identifies orphan Dart files and prunes with backup',
        () {
      final tempDir =
          Directory.systemTemp.createTempSync('appforge_file_test_');

      try {
        final libDir = Directory('${tempDir.path}/lib')
          ..createSync(recursive: true);
        final screensDir = Directory('${libDir.path}/screens')
          ..createSync(recursive: true);

        final mainFile = File('${libDir.path}/main.dart')..writeAsStringSync('''
          import 'screens/home.dart';
          void main() {}
        ''');
        final homeFile = File('${screensDir.path}/home.dart')
          ..writeAsStringSync('class HomeScreen {}');
        final deadFile = File('${screensDir.path}/abandoned.dart')
          ..writeAsStringSync('class DeadScreen {}');

        // Scan for orphan files
        final orphans = AppFileAuditor.findOrphanFiles(tempDir);
        expect(orphans.length, 1);
        expect(orphans.first.path.endsWith('abandoned.dart'), true);

        // Prune orphan files
        final prunedCount = AppFileAuditor.pruneOrphanFiles(
          orphans,
          projectDir: tempDir,
          createBackup: true,
        );

        expect(prunedCount, 1);
        expect(deadFile.existsSync(), false);
        expect(homeFile.existsSync(), true);
        expect(mainFile.existsSync(), true);

        // Verify moved to trash
        final trashFile =
            File('${tempDir.path}/.appforge_trash/files/abandoned.dart');
        expect(trashFile.existsSync(), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'AppCleanReverter restores pruned translations, assets, and files to exact paths',
        () {
      final tempDir =
          Directory.systemTemp.createTempSync('appforge_revert_test_');

      try {
        final libDir = Directory('${tempDir.path}/lib')
          ..createSync(recursive: true);
        final screensDir = Directory('${libDir.path}/screens')
          ..createSync(recursive: true);
        final assetsDir = Directory('${tempDir.path}/assets/images')
          ..createSync(recursive: true);

        // 1. Setup sample files
        final transFile = File('${libDir.path}/translations.dart')
          ..writeAsStringSync('''
import 'package:appforge/appforge.dart';
class AppTrans extends AppTranslations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': {
      'used': 'Used',
      'dead': 'Dead',
    },
  };
}
''');

        final assetFile = File('${assetsDir.path}/old_graphic.png')
          ..writeAsStringSync('binary_graphic_data');

        final orphanFile = File('${screensDir.path}/legacy_view.dart')
          ..writeAsStringSync('class LegacyView {}');

        // 2. Perform prune actions with backup
        // Prune translation
        AppCleanReverter.recordTranslationBackup(
          projectDir: tempDir,
          originalPath: transFile.path,
          backupPath: '${transFile.path}.bak',
        );
        AppTranslationAuditor.pruneUnusedKeys(
          file: transFile,
          unusedKeys: {'dead'},
          createBackup: true,
        );

        // Prune asset
        AppAssetAuditor.pruneUnusedAssets(
          [assetFile],
          projectDir: tempDir,
          createBackup: true,
        );

        // Prune file
        AppFileAuditor.pruneOrphanFiles(
          [orphanFile],
          projectDir: tempDir,
          createBackup: true,
        );

        // Verify files were pruned/modified
        expect(assetFile.existsSync(), false);
        expect(orphanFile.existsSync(), false);
        expect(transFile.readAsStringSync().contains("'dead'"), false);
        expect(File('${transFile.path}.bak').existsSync(), true);

        final trashDir = Directory('${tempDir.path}/.appforge_trash');
        expect(trashDir.existsSync(), true);

        // 3. Revert!
        final revertResult = AppCleanReverter.revert(tempDir);

        expect(revertResult.hasRestored, true);
        expect(revertResult.restoredTranslations, 1);
        expect(revertResult.restoredAssets, 1);
        expect(revertResult.restoredFiles, 1);
        expect(revertResult.totalRestored, 3);

        // 4. Verify all files restored to original locations and contents
        expect(assetFile.existsSync(), true);
        expect(assetFile.readAsStringSync(), 'binary_graphic_data');

        expect(orphanFile.existsSync(), true);
        expect(orphanFile.readAsStringSync(), 'class LegacyView {}');

        expect(transFile.existsSync(), true);
        expect(transFile.readAsStringSync().contains("'dead'"), true);
        expect(File('${transFile.path}.bak').existsSync(), false);

        // Verify trash directory was purged
        expect(trashDir.existsSync(), false);

        // 5. Running revert again should report nothing to revert
        final secondRevert = AppCleanReverter.revert(tempDir);
        expect(secondRevert.hasRestored, false);
        expect(secondRevert.totalRestored, 0);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test(
        'AppCommonTranslations resolves both standard and common_ prefixed keys',
        () {
      expect(AppCommonTranslations.resolve('close', 'en'), 'Close');
      expect(AppCommonTranslations.resolve('common_close', 'en'), 'Close');
      expect(AppCommonTranslations.resolve('close', 'ar'), 'إغلاق');
      expect(AppCommonTranslations.resolve('common_close', 'ar'), 'إغلاق');

      expect(AppCommonTranslations.resolve('ok', 'en'), 'OK');
      expect(AppCommonTranslations.resolve('common_ok', 'en'), 'OK');
      expect(AppCommonTranslations.resolve('ok', 'ar'), 'حسناً');
      expect(AppCommonTranslations.resolve('common_ok', 'ar'), 'حسناً');

      expect(AppCommonTranslations.isCommonKey('common_close'), true);
      expect(AppCommonTranslations.isCommonKey('close'), true);
      expect(AppCommonTranslations.isCommonKey('unknown_key'), false);
    });

    test(
        'AppLocalization tracks missing keys at runtime and reports them in auditTranslations',
        () {
      AppLocalization.instance.init(
        translations: SampleAuditedTranslations(),
        initialLocale: const Locale('en', 'US'),
      );
      AppLocalization.instance.clearMissingKeys();

      String? reportedKey;
      Locale? reportedLocale;
      AppLocalization.instance.onMissingKey = (key, locale) {
        reportedKey = key;
        reportedLocale = locale;
      };

      // 1. Existing key should not trigger missing tracking
      final welcome = 'welcome'.trParams({'name': 'Dhia'});
      expect(welcome, 'Welcome Dhia');
      expect(AppLocalization.instance.missingKeys.isEmpty, true);

      // 2. common_close is built-in and should not trigger missing tracking
      final close = 'common_close'.tr;
      expect(close, 'Close');
      expect(AppLocalization.instance.missingKeys.isEmpty, true);

      // 3. Truly missing key should be tracked and trigger onMissingKey
      final missingResult = 'completely_unknown_button_label'.tr;
      expect(missingResult, 'completely_unknown_button_label');
      expect(
          AppLocalization.instance.missingKeys
              .contains('completely_unknown_button_label'),
          true);
      expect(reportedKey, 'completely_unknown_button_label');
      expect(reportedLocale, const Locale('en', 'US'));

      // 4. App.auditTranslations reflects the missing key in unregisteredKeys
      final report = App.auditTranslations();
      expect(
          report.unregisteredKeys.contains('completely_unknown_button_label'),
          true);
      expect(report.isClean, false);

      AppLocalization.instance.clearMissingKeys();
      AppLocalization.instance.onMissingKey = null;
    });

    test(
        'scanDirectoryWithLocations extracts exact file and line number for missing keys',
        () {
      final tempDir = Directory.systemTemp.createTempSync('appforge_loc_test_');
      try {
        final screenFile = File('${tempDir.path}/screens/test_screen.dart');
        screenFile.parent.createSync(recursive: true);
        screenFile.writeAsStringSync('''
import 'package:flutter/material.dart';
import 'package:appforge/appforge.dart';

Widget buildUI() {
  return Text('missing_header_title'.tr);
}
''');

        final report = AppTranslationAuditor.scanProject(
          rootDir: tempDir,
          translations: SampleAuditedTranslations(),
        );

        expect(report.unregisteredKeys.contains('missing_header_title'), true);
        final locs = report.unregisteredKeyLocations['missing_header_title'];
        expect(locs != null, true);
        expect(locs!.any((l) => l.contains('test_screen.dart:5')), true);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });
}
