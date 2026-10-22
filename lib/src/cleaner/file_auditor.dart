import 'dart:io';
import 'revert_manager.dart';

/// Zero-dependency orphan Dart file auditor.
///
/// Detects unimported and unexported `.dart` files inside `lib/` (dead screens,
/// obsolete widgets, and abandoned modules) that have zero references across
/// the codebase.
class AppFileAuditor {
  AppFileAuditor._();

  /// Regex pattern matching Dart import, export, and part directives.
  static final RegExp _directiveRegex = RegExp(
    r'''\b(?:import|export|part)\s+['"]([^'"]+)['"]''',
  );

  /// Scans [projectDir]/lib for `.dart` files and returns all orphan files that
  /// are never imported or exported by any file in `lib/`, `test/`, or `bin/`.
  static List<File> findOrphanFiles(
    Directory projectDir, {
    List<String> entryPointNames = const ['main.dart', 'appforge.dart'],
    List<String> ignoredDirectories = const [
      '.git',
      '.dart_tool',
      'build',
      '.idea',
      '.agents',
    ],
  }) {
    final libDir = Directory('${projectDir.path}/lib');
    if (!libDir.existsSync()) return const [];

    // 1. Collect all .dart files in lib/
    final allLibFiles = libDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    if (allLibFiles.isEmpty) return const [];

    // 2. Collect all scanner directories to search for imports (lib/, test/, bin/)
    final searchDirs = [
      libDir,
      Directory('${projectDir.path}/test'),
      Directory('${projectDir.path}/bin'),
    ].where((d) => d.existsSync()).toList();

    // 3. Extract all imported/exported target paths and package URIs
    final referencedTargetPaths = <String>{};
    final referencedPackageUris = <String>{};

    for (final dir in searchDirs) {
      final entities = dir.listSync(recursive: true, followLinks: false);
      for (final entity in entities) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;

        // Skip ignored directories
        final segments = entity.uri.pathSegments;
        if (ignoredDirectories.any((ign) => segments.contains(ign))) continue;

        try {
          final content = entity.readAsStringSync();
          final matches = _directiveRegex.allMatches(content);
          for (final m in matches) {
            final uri = m.group(1);
            if (uri == null || uri.isEmpty) continue;

            if (uri.startsWith('package:')) {
              referencedPackageUris.add(_normalizePath(uri));
            } else if (!uri.startsWith('dart:')) {
              // Relative import: resolve against entity.parent directory
              try {
                final parentUri = Uri.file('${entity.parent.path}/');
                final resolved = parentUri.resolve(uri).toFilePath();
                referencedTargetPaths.add(_normalizePath(resolved));
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    }

    // 4. Identify orphan files in lib/
    final orphanFiles = <File>[];
    final packageName = _getPackageName(projectDir);

    for (final file in allLibFiles) {
      final fileName = file.uri.pathSegments.last;

      // Skip entry points like main.dart or package barrel (appforge.dart)
      if (entryPointNames.contains(fileName)) continue;

      final normFilePath = _normalizePath(file.path);

      // Relative path from lib/ (e.g. 'screens/old_screen.dart')
      final relFromLib = _normalizePath(
        file.path.substring(libDir.path.length + 1),
      );

      // Package URI (e.g. 'package:my_app/screens/old_screen.dart')
      final packageUri =
          packageName != null ? 'package:$packageName/$relFromLib' : null;

      // Check if file is referenced by canonical path or package URI
      final isReferenced = referencedTargetPaths.contains(normFilePath) ||
          (packageUri != null && referencedPackageUris.contains(packageUri));

      if (!isReferenced) {
        // Also check if file has @pragma('vm:entry-point')
        try {
          final content = file.readAsStringSync();
          if (content.contains("@pragma('vm:entry-point')") ||
              content.contains('@pragma("vm:entry-point")')) {
            continue;
          }
        } catch (_) {}

        orphanFiles.add(file);
      }
    }

    orphanFiles.sort((a, b) => a.path.compareTo(b.path));
    return orphanFiles;
  }

  /// Automatically moves [orphanFiles] to `.appforge_trash/files/` (or deletes them).
  ///
  /// If [createBackup] is true, files are moved to `.appforge_trash/files/`.
  /// Returns the number of files successfully cleaned.
  static int pruneOrphanFiles(
    List<File> orphanFiles, {
    required Directory projectDir,
    bool createBackup = true,
  }) {
    if (orphanFiles.isEmpty) return 0;

    int count = 0;
    final trashDir = Directory('${projectDir.path}/.appforge_trash/files');
    if (createBackup && !trashDir.existsSync()) {
      trashDir.createSync(recursive: true);
    }

    for (final file in orphanFiles) {
      if (!file.existsSync()) continue;

      try {
        if (createBackup) {
          String fileName = file.uri.pathSegments.last;
          var dest = File('${trashDir.path}/$fileName');
          int collisionIdx = 1;
          while (dest.existsSync()) {
            fileName = '${collisionIdx++}_${file.uri.pathSegments.last}';
            dest = File('${trashDir.path}/$fileName');
          }
          file.copySync(dest.path);
          AppCleanReverter.recordTrashItem(
            projectDir: projectDir,
            category: 'files',
            originalPath: file.path,
            trashedFile: dest,
          );
        }
        file.deleteSync();
        count++;
      } catch (_) {}
    }

    return count;
  }

  static String? _getPackageName(Directory projectDir) {
    final pubspec = File('${projectDir.path}/pubspec.yaml');
    if (!pubspec.existsSync()) return null;

    try {
      final lines = pubspec.readAsLinesSync();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('name:')) {
          return trimmed.substring(5).trim();
        }
      }
    } catch (_) {}

    return null;
  }

  static String _normalizePath(String path) {
    return path.replaceAll(r'\', '/');
  }
}
