import 'dart:convert';
import 'dart:io';

import 'storage_types.dart';

Directory resolvePlatformStorageDirectory({bool allowTempFallback = false}) {
  if (Platform.isIOS) {
    final appRoot = Directory.systemTemp.parent.path;
    // Verify we are inside an iOS app sandbox (which always contains Library/).
    if (Directory('$appRoot/Library').existsSync()) {
      // Apple's designated location for app-managed data files: hidden from
      // the Files app and never purged by the OS (unlike tmp/ and Caches/).
      return Directory('$appRoot/Library/Application Support');
    }
  } else if (Platform.isAndroid) {
    final appRoot = Directory.systemTemp.parent.path;
    final appFlutter = Directory('$appRoot/app_flutter');
    if (appFlutter.existsSync()) return appFlutter;
    final files = Directory('$appRoot/files');
    if (files.existsSync()) return files;
    if (Directory('$appRoot/cache').existsSync() ||
        Directory('$appRoot/shared_prefs').existsSync()) {
      return files;
    }
  } else if (Platform.isMacOS) {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return Directory(
        '$home/Library/Application Support/${_applicationFolderName()}',
      );
    }
  } else if (Platform.isWindows) {
    final appData =
        Platform.environment['APPDATA'] ?? Platform.environment['LOCALAPPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory('$appData\\${_applicationFolderName()}');
    }
  } else if (Platform.isLinux) {
    final xdgData = Platform.environment['XDG_DATA_HOME'];
    final home = Platform.environment['HOME'];
    final base = (xdgData != null && xdgData.isNotEmpty)
        ? xdgData
        : (home != null && home.isNotEmpty ? '$home/.local/share' : null);
    if (base != null) {
      return Directory('$base/${_applicationFolderName()}');
    }
  }

  if (allowTempFallback) {
    return Directory('${Directory.systemTemp.path}/appforge_data');
  }

  throw StateError(
    'AppStorage could not resolve a persistent application directory on '
    '${Platform.operatingSystem}. Pass `path` or `pathResolver` to '
    'AppStorage.init() (or set allowTempFallback: true for non-persistent '
    'test environments).',
  );
}

String _applicationFolderName() {
  final segments = Uri.file(Platform.resolvedExecutable)
      .pathSegments
      .where((s) => s.isNotEmpty)
      .toList();
  if (segments.isEmpty) return 'appforge';
  final exe =
      segments.last.replaceAll(RegExp(r'\.exe$', caseSensitive: false), '');
  final sanitized = exe.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  return sanitized.isEmpty ? 'appforge' : sanitized;
}

String computeStorageTargetId({
  required String container,
  required String? resolvedPath,
  required bool allowTempFallback,
}) {
  final autoResolve = resolvedPath == null || resolvedPath.isEmpty;
  final baseDir = autoResolve
      ? resolvePlatformStorageDirectory(allowTempFallback: allowTempFallback)
      : Directory(resolvedPath);

  if (!baseDir.existsSync()) {
    baseDir.createSync(recursive: true);
  }
  return '${baseDir.path}${Platform.pathSeparator}.appforge_$container.json';
}

void migrateLegacyStorageIfNeeded({
  required String container,
  required String targetId,
  required StorageBackendReporter onReport,
}) {
  final target = File(targetId);
  if (target.existsSync() || !Platform.isIOS) return;
  final appRoot = Directory.systemTemp.parent.path;
  final legacy = File('$appRoot/Documents/.appforge_$container.json');
  if (!legacy.existsSync()) return;
  try {
    legacy.renameSync(target.path);
  } catch (error, stack) {
    onReport(
        error, stack, 'while migrating legacy storage file ${legacy.path}');
  }
}

Map<String, Object?> loadStorageData(
  String targetId, {
  AppStorageCodec? codec,
  required StorageBackendReporter onReport,
  bool throwOnCorrupt = false,
}) {
  final file = File(targetId);
  final swaps = [File('${file.path}.tmp'), File('${file.path}.sync.tmp')];

  final (committed, committedError) = _tryDecode(file, codec);
  if (committed != null) {
    for (final swap in swaps) {
      _deleteFile(swap, onReport);
    }
    return committed;
  }

  final intact = <(File, Map<String, Object?>)>[];
  (Object, StackTrace)? swapError;
  for (final swap in swaps) {
    final (decoded, err) = _tryDecode(swap, codec);
    if (decoded != null) {
      intact.add((swap, decoded));
    } else {
      swapError ??= err;
    }
  }

  if (intact.isEmpty) {
    final err = committedError ?? swapError;
    if (err != null) {
      onReport(err.$1, err.$2, 'while loading storage file ${file.path}');
      if (throwOnCorrupt) {
        Error.throwWithStackTrace(err.$1, err.$2);
      }
    }
    return <String, Object?>{};
  }

  if (committedError != null) {
    onReport(
      committedError.$1,
      committedError.$2,
      'while loading primary storage file ${file.path} (recovered from swap)',
    );
  }

  intact.sort(
      (a, b) => b.$1.lastModifiedSync().compareTo(a.$1.lastModifiedSync()));
  final (newest, data) = intact.first;
  try {
    newest.renameSync(file.path);
  } catch (error, stack) {
    onReport(error, stack, 'while promoting swap file ${newest.path}');
    if (throwOnCorrupt) rethrow;
  }
  for (final swap in swaps) {
    _deleteFile(swap, onReport);
  }
  return data;
}

(Map<String, Object?>?, (Object, StackTrace)?) _tryDecode(
  File file,
  AppStorageCodec? codec,
) {
  if (!file.existsSync()) return (null, null);
  try {
    final rawBytes = file.readAsBytesSync();
    if (rawBytes.isEmpty) {
      throw FormatException('Storage file is empty: ${file.path}');
    }
    final plainBytes = codec != null ? codec.decode(rawBytes) : rawBytes;
    final content = utf8.decode(plainBytes);
    final decoded = json.decode(content);
    if (decoded is! Map) {
      throw FormatException(
        'Expected JSON object in ${file.path}, found ${decoded.runtimeType}',
      );
    }
    return (Map<String, Object?>.from(decoded), null);
  } catch (error, stack) {
    return (null, (error, stack));
  }
}

void writeStorageSync(
  String targetId,
  List<int> bytes, {
  bool isEncoded = false,
}) {
  final file = File(targetId);
  final tmp = File('${file.path}.sync.tmp');
  final raf = tmp.openSync(mode: FileMode.write);
  try {
    raf.writeFromSync(bytes);
    raf.flushSync();
  } finally {
    raf.closeSync();
  }
  tmp.renameSync(file.path);
}

Future<void> writeStorageAtomic(
  String targetId,
  List<int> bytes, {
  bool isEncoded = false,
  required bool Function() shouldCommit,
  required void Function() onCommitted,
  required StorageBackendReporter onReport,
}) async {
  final file = File(targetId);
  final tmp = File('${file.path}.tmp');
  final raf = await tmp.open(mode: FileMode.write);
  try {
    await raf.writeFrom(bytes);
    await raf.flush(); // fsync: bytes are on stable storage before the swap
  } finally {
    await raf.close();
  }

  if (shouldCommit()) {
    tmp.renameSync(file.path);
    onCommitted();
  } else {
    _deleteFile(tmp, onReport);
  }
}

void deleteStorageTarget(
  String targetId, {
  required StorageBackendReporter onReport,
}) {
  final file = File(targetId);
  for (final target in [
    file,
    File('${file.path}.tmp'),
    File('${file.path}.sync.tmp'),
  ]) {
    _deleteFile(target, onReport);
  }
}

void _deleteFile(File file, StorageBackendReporter onReport) {
  try {
    if (file.existsSync()) file.deleteSync();
  } catch (error, stack) {
    onReport(error, stack, 'while deleting swap file ${file.path}');
  }
}
