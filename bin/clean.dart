import 'dart:convert';
import 'dart:io';
import 'package:appforge/src/cleaner/asset_auditor.dart';
import 'package:appforge/src/cleaner/audit_report.dart';
import 'package:appforge/src/cleaner/file_auditor.dart';
import 'package:appforge/src/cleaner/revert_manager.dart';
import 'package:appforge/src/cleaner/translation_auditor.dart';

/// AppForge Project Cleaner CLI.
///
/// Usage:
/// ```bash
/// dart run appforge:clean [path] [--translations] [--assets] [--files] [--all] [--fix] [--revert] [--no-backup] [--json]
/// ```
void main(List<String> args) {
  bool isFixMode = false;
  bool isRevertMode = false;
  bool isJsonMode = false;
  bool createBackup = true;
  bool checkTranslations = false;
  bool checkAssets = false;
  bool checkFiles = false;
  String? targetPath;

  for (final arg in args) {
    if (arg == '--fix' || arg == '-f') {
      isFixMode = true;
    } else if (arg == '--revert' || arg == '-r') {
      isRevertMode = true;
    } else if (arg == '--no-backup') {
      createBackup = false;
    } else if (arg == '--json') {
      isJsonMode = true;
    } else if (arg == '--translations' || arg == '-t') {
      checkTranslations = true;
    } else if (arg == '--assets' || arg == '-a') {
      checkAssets = true;
    } else if (arg == '--files') {
      checkFiles = true;
    } else if (arg == '--all') {
      checkTranslations = true;
      checkAssets = true;
      checkFiles = true;
    } else if (arg == '--help' || arg == '-h') {
      _printHelp();
      return;
    } else if (!arg.startsWith('-')) {
      targetPath = arg;
    }
  }

  targetPath ??= Directory.current.path;
  final dir = Directory(targetPath);

  if (!dir.existsSync()) {
    stderr.writeln('\x1B[31merror: directory not found: $targetPath\x1B[0m');
    exit(1);
  }

  // Handle --revert mode immediately
  if (isRevertMode) {
    if (!isJsonMode) {
      stdout.writeln('AppForge Cleaner');
      stdout.writeln('Reverting in: ${dir.path}\n');
    }
    final revertResult = AppCleanReverter.revert(dir);
    if (isJsonMode) {
      stdout.writeln(json.encode({
        'reverted': revertResult.hasRestored,
        'restoredTranslations': revertResult.restoredTranslations,
        'restoredAssets': revertResult.restoredAssets,
        'restoredFiles': revertResult.restoredFiles,
      }));
      return;
    }
    if (revertResult.hasRestored) {
      stdout.writeln(
        '\x1B[32mRevert complete: restored ${revertResult.restoredTranslations} translation(s), ${revertResult.restoredAssets} asset(s), ${revertResult.restoredFiles} file(s).\x1B[0m\n',
      );
    } else {
      stdout.writeln(
        '\x1B[33mNothing to revert: no backups or .appforge_trash found in ${dir.path}.\x1B[0m\n',
      );
    }
    return;
  }

  // If no specific mode flag was selected, default to checking all
  if (!checkTranslations && !checkAssets && !checkFiles) {
    checkTranslations = true;
    checkAssets = true;
    checkFiles = true;
  }

  final results = <String, dynamic>{};
  int totalIssues = 0;

  if (!isJsonMode) {
    stdout.writeln('AppForge Cleaner');
    stdout.writeln('Scanning: ${dir.path}\n');
  }

  // ==========================================
  // 1. Audit Translations
  // ==========================================
  List<DiscoveredTranslationFile> translationFiles = [];
  AppAuditReport? translationReport;
  final keyLocations = <String, String>{};

  if (checkTranslations) {
    translationFiles = AppTranslationAuditor.findTranslationFiles(dir);
    if (translationFiles.isNotEmpty) {
      final combinedKeys = <String, Map<String, String>>{};
      for (final tf in translationFiles) {
        for (final locEntry in tf.keysByLocale.entries) {
          final loc = locEntry.key;
          combinedKeys.putIfAbsent(loc, () => {});
          combinedKeys[loc]!.addAll(locEntry.value);
        }
        for (final lineEntry in tf.keyLineNumbers.entries) {
          keyLocations[lineEntry.key] = '${tf.file.path}:${lineEntry.value}';
        }
      }

      final report = AppTranslationAuditor.scanProject(
        rootDir: dir,
        translations: combinedKeys,
      );
      translationReport = report;
      totalIssues += report.unusedKeys.length +
          report.missingKeys.values.expand((k) => k).length +
          report.unregisteredKeys.length;

      results['translations'] = {
        ...report.toJson(),
        'keyLocations': keyLocations,
      };

      if (!isJsonMode) {
        if (report.unusedKeys.isNotEmpty) {
          stdout.writeln(
              '\x1B[33mUnused translation keys (${report.unusedKeys.length}):\x1B[0m');
          for (final k in report.unusedKeys) {
            final loc = keyLocations[k] != null
                ? '  \x1B[90m${keyLocations[k]}\x1B[0m'
                : '';
            stdout.writeln('  $k$loc');
          }
          stdout.writeln('');
        }

        if (report.missingKeys.isNotEmpty) {
          stdout.writeln('\x1B[31mMissing keys per locale:\x1B[0m');
          report.missingKeys.forEach((locale, keys) {
            stdout.writeln('  $locale: ${keys.join(', ')}');
          });
          stdout.writeln('');
        }

        if (report.unregisteredKeys.isNotEmpty) {
          stdout.writeln(
              '\x1B[31mMissing translation keys in code (not defined in any locale) (${report.unregisteredKeys.length}):\x1B[0m');
          for (final k in report.unregisteredKeys) {
            final locs = report.unregisteredKeyLocations[k];
            final loc = locs != null && locs.isNotEmpty
                ? '  \x1B[90m${locs.join(', ')}\x1B[0m'
                : '';
            stdout.writeln('  $k$loc');
          }
          stdout.writeln('');
        }
      }
    }
  }

  // ==========================================
  // 2. Audit Unused Assets
  // ==========================================
  List<File> unusedAssets = [];
  if (checkAssets) {
    unusedAssets = AppAssetAuditor.findUnusedAssets(dir);
    totalIssues += unusedAssets.length;
    results['unusedAssets'] = unusedAssets.map((f) => f.path).toList();

    if (!isJsonMode && unusedAssets.isNotEmpty) {
      stdout.writeln('\x1B[33mUnused assets (${unusedAssets.length}):\x1B[0m');
      for (final a in unusedAssets) {
        final relPath = a.path.startsWith(dir.path)
            ? a.path.substring(dir.path.length + 1)
            : a.path;
        stdout.writeln('  $relPath');
      }
      stdout.writeln('');
    }
  }

  // ==========================================
  // 3. Audit Orphan Dart Files
  // ==========================================
  List<File> orphanFiles = [];
  if (checkFiles) {
    orphanFiles = AppFileAuditor.findOrphanFiles(dir);
    totalIssues += orphanFiles.length;
    results['orphanFiles'] = orphanFiles.map((f) => f.path).toList();

    if (!isJsonMode && orphanFiles.isNotEmpty) {
      stdout.writeln(
          '\x1B[33mOrphan Dart files (0 imports/exports) (${orphanFiles.length}):\x1B[0m');
      for (final f in orphanFiles) {
        final relPath = f.path.startsWith(dir.path)
            ? f.path.substring(dir.path.length + 1)
            : f.path;
        stdout.writeln('  $relPath');
      }
      stdout.writeln('');
    }
  }

  // JSON output mode
  if (isJsonMode) {
    results['totalIssues'] = totalIssues;
    results['isClean'] = totalIssues == 0;
    stdout.writeln(json.encode(results));
    return;
  }

  // ==========================================
  // 4. Handle --fix Mode or Print Summary
  // ==========================================
  if (isFixMode && totalIssues > 0) {
    stdout.writeln('Fix mode active: Pruning unused resources...\n');
    int prunedTranslations = 0;
    int prunedAssets = 0;
    int prunedFiles = 0;

    // Prune unused translations
    if (translationReport != null && translationReport.unusedKeys.isNotEmpty) {
      for (final tf in translationFiles) {
        if (createBackup) {
          AppCleanReverter.recordTranslationBackup(
            projectDir: dir,
            originalPath: tf.file.path,
            backupPath: '${tf.file.path}.bak',
          );
        }
        final count = AppTranslationAuditor.pruneUnusedKeys(
          file: tf.file,
          unusedKeys: translationReport.unusedKeys,
          createBackup: createBackup,
        );
        prunedTranslations += count;
        if (count > 0) {
          final backupMsg =
              createBackup ? ' (backup: ${tf.file.path}.bak)' : '';
          stdout
              .writeln('  pruned $count key(s) from ${tf.file.path}$backupMsg');
        }
      }
    }

    // Prune unused assets
    if (unusedAssets.isNotEmpty) {
      prunedAssets = AppAssetAuditor.pruneUnusedAssets(
        unusedAssets,
        projectDir: dir,
        createBackup: createBackup,
      );
      final destMsg = createBackup ? ' (moved to .appforge_trash/assets/)' : '';
      stdout.writeln('  removed $prunedAssets unused asset(s)$destMsg');
    }

    // Prune orphan files
    if (orphanFiles.isNotEmpty) {
      prunedFiles = AppFileAuditor.pruneOrphanFiles(
        orphanFiles,
        projectDir: dir,
        createBackup: createBackup,
      );
      final destMsg = createBackup ? ' (moved to .appforge_trash/files/)' : '';
      stdout.writeln('  removed $prunedFiles orphan file(s)$destMsg');
    }

    stdout.writeln(
        '\n\x1B[32mClean complete: $prunedTranslations translation(s), $prunedAssets asset(s), $prunedFiles file(s) pruned.\x1B[0m\n');
    exit(0);
  }

  // Clean Summary
  if (totalIssues == 0) {
    stdout.writeln(
        '\x1B[32mClean: Zero dead translations, unused assets, or orphan files found.\x1B[0m\n');
  } else {
    final parts = <String>[];
    if (translationReport != null &&
        translationReport.unregisteredKeys.isNotEmpty) {
      parts.add(
          '${translationReport.unregisteredKeys.length} missing translation key(s) in code');
    }
    if (translationReport != null && translationReport.missingKeys.isNotEmpty) {
      final totalMissing = translationReport.missingKeys.values
          .fold<int>(0, (sum, list) => sum + list.length);
      parts.add('$totalMissing missing locale key(s)');
    }
    if (translationReport != null && translationReport.unusedKeys.isNotEmpty) {
      parts.add('${translationReport.unusedKeys.length} unused translation(s)');
    }
    if (unusedAssets.isNotEmpty) {
      parts.add('${unusedAssets.length} unused asset(s)');
    }
    if (orphanFiles.isNotEmpty) {
      parts.add('${orphanFiles.length} orphan file(s)');
    }

    stdout.writeln('Summary: ${parts.join(' | ')}');
    stdout.writeln(
        '\x1B[90mRun `dart run appforge:clean --fix` to prune unused resources.\x1B[0m');
    stdout.writeln(
        '\x1B[90mNote: To clean unused Dart imports/private elements, use `dart fix --apply`.\x1B[0m\n');
    exit(1);
  }
}

void _printHelp() {
  stdout.writeln('''
AppForge Project Cleaner

Usage:
  dart run appforge:clean [path] [flags]

Flags:
  -f, --fix            Automatically remove unused translations, assets, and orphan files.
  -r, --revert         Roll back changes from a previous --fix run (restores files from backup/.appforge_trash).
  -a, --assets         Audit only assets/ directory.
  -t, --translations   Audit only translation dictionaries.
      --files          Audit only orphan Dart files.
      --all            Audit all (translations, assets, orphan files) [default].
      --no-backup      Skip creating backups during --fix.
      --json           Output raw JSON results for CI/CD integration.
  -h, --help           Show this help dialog.

Examples:
  dart run appforge:clean
  dart run appforge:clean --fix
  dart run appforge:clean --revert
  dart run appforge:clean --assets
  dart run appforge:clean --json
''');
}
