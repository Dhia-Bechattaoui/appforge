import 'dart:io';
import 'revert_manager.dart';

/// Zero-dependency asset auditor.
///
/// Scans the `assets/` directory (or assets configured in `pubspec.yaml`) and
/// cross-references them against Dart source code in `lib/` to detect unreferenced
/// images, icons, fonts, and files that bloat the application bundle.
class AppAssetAuditor {
  AppAssetAuditor._();

  /// Scans [projectDir] for assets and checks if each asset is referenced anywhere in [projectDir]/lib.
  ///
  /// Returns a list of [File]s in `assets/` that have zero references in source code.
  static List<File> findUnusedAssets(
    Directory projectDir, {
    List<String> assetDirectories = const ['assets', 'asset'],
    List<String> ignoredExtensions = const ['.DS_Store', '.gitkeep'],
  }) {
    if (!projectDir.existsSync()) return const [];

    // 1. Collect all asset files
    final assetFiles = <File>[];
    for (final dirName in assetDirectories) {
      final dir = Directory('${projectDir.path}/$dirName');
      if (dir.existsSync()) {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final fileName = entity.uri.pathSegments.last;
            if (ignoredExtensions.any((ext) => fileName.endsWith(ext))) {
              continue;
            }
            assetFiles.add(entity);
          }
        }
      }
    }

    if (assetFiles.isEmpty) return const [];

    // 2. Read all source files in lib/
    final libDir = Directory('${projectDir.path}/lib');
    if (!libDir.existsSync()) return assetFiles;

    final codeFiles = libDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Cache source code content for fast substring searches
    final sourceContents = <String>[];
    for (final f in codeFiles) {
      try {
        sourceContents.add(f.readAsStringSync());
      } catch (_) {}
    }

    // 3. Check usage of each asset
    final unusedAssets = <File>[];

    for (final asset in assetFiles) {
      final fileName = asset.uri.pathSegments.last;
      final fullRelativePath = _normalizePath(
        asset.path.substring(projectDir.path.length + 1),
      );

      // An asset is considered used if its full relative path (e.g. 'assets/images/cat.png'),
      // or its filename (e.g. 'cat.png') is found in any Dart source file.
      final isUsed = sourceContents.any((code) {
        return code.contains(fullRelativePath) || code.contains(fileName);
      });

      if (!isUsed) {
        unusedAssets.add(asset);
      }
    }

    unusedAssets.sort((a, b) => a.path.compareTo(b.path));
    return unusedAssets;
  }

  /// Automatically moves [unusedAssets] to an `.appforge_trash/assets/` directory (or deletes them).
  ///
  /// If [createBackup] is true, files are moved to `.appforge_trash/assets/`.
  /// Returns the number of assets successfully cleaned.
  static int pruneUnusedAssets(
    List<File> unusedAssets, {
    required Directory projectDir,
    bool createBackup = true,
  }) {
    if (unusedAssets.isEmpty) return 0;

    int count = 0;
    final trashDir = Directory('${projectDir.path}/.appforge_trash/assets');
    if (createBackup && !trashDir.existsSync()) {
      trashDir.createSync(recursive: true);
    }

    for (final asset in unusedAssets) {
      if (!asset.existsSync()) continue;

      try {
        if (createBackup) {
          String fileName = asset.uri.pathSegments.last;
          var dest = File('${trashDir.path}/$fileName');
          int collisionIdx = 1;
          while (dest.existsSync()) {
            fileName = '${collisionIdx++}_${asset.uri.pathSegments.last}';
            dest = File('${trashDir.path}/$fileName');
          }
          asset.copySync(dest.path);
          AppCleanReverter.recordTrashItem(
            projectDir: projectDir,
            category: 'assets',
            originalPath: asset.path,
            trashedFile: dest,
          );
        }
        asset.deleteSync();
        count++;
      } catch (_) {}
    }

    return count;
  }

  static String _normalizePath(String path) {
    return path.replaceAll(r'\', '/');
  }
}
