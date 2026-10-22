import 'dart:convert';
import 'dart:io';

/// Manages backups and provides zero-dependency one-command rollback for AppForge cleaners.
///
/// When `appforge:clean --fix` runs, pruned assets and orphan files are moved
/// to `.appforge_trash/` with their original paths recorded in `.appforge_trash/manifest.json`.
/// Translation files are copied to `<file>.bak`.
///
/// Running `appforge:clean --revert` restores all files to their exact original paths.
class AppCleanReverter {
  AppCleanReverter._();

  static const String trashDirName = '.appforge_trash';
  static const String manifestFileName = 'manifest.json';

  /// Records a pruned asset or file in the trash manifest.
  static void recordTrashItem({
    required Directory projectDir,
    required String category, // 'assets' or 'files'
    required String originalPath,
    required File trashedFile,
  }) {
    final trashDir = Directory('${projectDir.path}/$trashDirName');
    if (!trashDir.existsSync()) {
      trashDir.createSync(recursive: true);
    }

    final manifestFile = File('${trashDir.path}/$manifestFileName');
    Map<String, dynamic> manifest = {};

    if (manifestFile.existsSync()) {
      try {
        manifest = json.decode(manifestFile.readAsStringSync())
            as Map<String, dynamic>;
      } catch (_) {}
    }

    manifest.putIfAbsent(category, () => <String, dynamic>{});
    (manifest[category]
            as Map<String, dynamic>)[trashedFile.uri.pathSegments.last] =
        originalPath;

    manifestFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(manifest));
  }

  /// Records a backed up translation file.
  static void recordTranslationBackup({
    required Directory projectDir,
    required String originalPath,
    required String backupPath,
  }) {
    final trashDir = Directory('${projectDir.path}/$trashDirName');
    if (!trashDir.existsSync()) {
      trashDir.createSync(recursive: true);
    }

    final manifestFile = File('${trashDir.path}/$manifestFileName');
    Map<String, dynamic> manifest = {};

    if (manifestFile.existsSync()) {
      try {
        manifest = json.decode(manifestFile.readAsStringSync())
            as Map<String, dynamic>;
      } catch (_) {}
    }

    manifest.putIfAbsent('translations', () => <String, dynamic>{});
    (manifest['translations'] as Map<String, dynamic>)[backupPath] =
        originalPath;

    manifestFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(manifest));
  }

  /// Reverts all changes made by previous `appforge:clean --fix` operations.
  ///
  /// Restores translations from `.bak` copies and moves files from `.appforge_trash/`
  /// back to their original locations.
  static CleanRevertResult revert(Directory projectDir) {
    int restoredTranslations = 0;
    int restoredAssets = 0;
    int restoredFiles = 0;

    final trashDir = Directory('${projectDir.path}/$trashDirName');
    final manifestFile = File('${trashDir.path}/$manifestFileName');

    // 1. Revert using manifest if present
    if (manifestFile.existsSync()) {
      try {
        final manifest = json.decode(manifestFile.readAsStringSync())
            as Map<String, dynamic>;

        // Revert translations
        if (manifest.containsKey('translations')) {
          final transMap = manifest['translations'] as Map<String, dynamic>;
          for (final entry in transMap.entries) {
            final backupFile = File(entry.key);
            final origFile = File(entry.value.toString());
            if (backupFile.existsSync()) {
              backupFile.copySync(origFile.path);
              backupFile.deleteSync();
              restoredTranslations++;
            }
          }
        }

        // Revert assets
        if (manifest.containsKey('assets')) {
          final assetMap = manifest['assets'] as Map<String, dynamic>;
          for (final entry in assetMap.entries) {
            final trashedFile = File('${trashDir.path}/assets/${entry.key}');
            final destFile = File(entry.value.toString());
            if (trashedFile.existsSync()) {
              if (!destFile.parent.existsSync()) {
                destFile.parent.createSync(recursive: true);
              }
              trashedFile.copySync(destFile.path);
              trashedFile.deleteSync();
              restoredAssets++;
            }
          }
        }

        // Revert orphan files
        if (manifest.containsKey('files')) {
          final fileMap = manifest['files'] as Map<String, dynamic>;
          for (final entry in fileMap.entries) {
            final trashedFile = File('${trashDir.path}/files/${entry.key}');
            final destFile = File(entry.value.toString());
            if (trashedFile.existsSync()) {
              if (!destFile.parent.existsSync()) {
                destFile.parent.createSync(recursive: true);
              }
              trashedFile.copySync(destFile.path);
              trashedFile.deleteSync();
              restoredFiles++;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: Scan project recursively for any orphan .bak files
    final entities = projectDir.listSync(recursive: true, followLinks: false);
    for (final entity in entities) {
      if (entity is File && entity.path.endsWith('.bak')) {
        final origPath = entity.path.substring(0, entity.path.length - 4);
        final origFile = File(origPath);
        entity.copySync(origFile.path);
        entity.deleteSync();
        restoredTranslations++;
      }
    }

    // 3. Remove trash directory once restored
    if (trashDir.existsSync()) {
      try {
        trashDir.deleteSync(recursive: true);
      } catch (_) {}
    }

    return CleanRevertResult(
      restoredTranslations: restoredTranslations,
      restoredAssets: restoredAssets,
      restoredFiles: restoredFiles,
    );
  }
}

/// Result of an AppForge cleaner revert operation.
class CleanRevertResult {
  const CleanRevertResult({
    required this.restoredTranslations,
    required this.restoredAssets,
    required this.restoredFiles,
  });

  final int restoredTranslations;
  final int restoredAssets;
  final int restoredFiles;

  int get totalRestored =>
      restoredTranslations + restoredAssets + restoredFiles;

  bool get hasRestored => totalRestored > 0;
}
