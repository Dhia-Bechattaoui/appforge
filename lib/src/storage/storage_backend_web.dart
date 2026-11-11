import 'dart:convert';
import 'dart:js_interop';

import '../platform/io_shim.dart';
import 'storage_types.dart';

@JS('window.localStorage')
external _JsWebStorage? get _browserLocalStorage;

extension type _JsWebStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

final Map<String, String> _memoryFallback = <String, String>{};

Directory resolvePlatformStorageDirectory({bool allowTempFallback = false}) {
  throw UnsupportedError(
    'Directory resolution is not supported on Flutter Web; AppStorage persists '
    'automatically via browser localStorage.',
  );
}

String computeStorageTargetId({
  required String container,
  required String? resolvedPath,
  required bool allowTempFallback,
}) =>
    'appforge_$container';

void migrateLegacyStorageIfNeeded({
  required String container,
  required String targetId,
  required StorageBackendReporter onReport,
}) {}

Map<String, Object?> loadStorageData(
  String targetId, {
  AppStorageCodec? codec,
  required StorageBackendReporter onReport,
  bool throwOnCorrupt = false,
}) {
  try {
    final raw = _readRaw(targetId);
    if (raw == null || raw.isEmpty) return <String, Object?>{};

    final String jsonString;
    if (codec != null) {
      final decodedBytes = codec.decode(base64Decode(raw));
      jsonString = utf8.decode(decodedBytes);
    } else {
      jsonString = raw;
    }

    final decoded = json.decode(jsonString);
    if (decoded is! Map) {
      throw FormatException(
        'Expected JSON object in localStorage["$targetId"], found ${decoded.runtimeType}',
      );
    }
    return Map<String, Object?>.from(decoded);
  } catch (error, stack) {
    onReport(error, stack, 'while loading web storage "$targetId"');
    if (throwOnCorrupt) {
      Error.throwWithStackTrace(error, stack);
    }
    return <String, Object?>{};
  }
}

void writeStorageSync(String targetId, List<int> bytes,
    {bool isEncoded = false}) {
  _writeEncoded(targetId, bytes, isEncoded: isEncoded);
}

Future<void> writeStorageAtomic(
  String targetId,
  List<int> bytes, {
  bool isEncoded = false,
  required bool Function() shouldCommit,
  required void Function() onCommitted,
  required StorageBackendReporter onReport,
}) async {
  if (shouldCommit()) {
    _writeEncoded(targetId, bytes, isEncoded: isEncoded);
    onCommitted();
  }
}

void deleteStorageTarget(
  String targetId, {
  required StorageBackendReporter onReport,
}) {
  try {
    final storage = _browserLocalStorage;
    if (storage != null) {
      storage.removeItem(targetId);
    }
    _memoryFallback.remove(targetId);
  } catch (error, stack) {
    onReport(error, stack, 'while deleting web storage "$targetId"');
  }
}

String? _readRaw(String key) {
  final storage = _browserLocalStorage;
  if (storage != null) {
    return storage.getItem(key);
  }
  return _memoryFallback[key];
}

void _writeEncoded(
  String targetId,
  List<int> bytes, {
  required bool isEncoded,
}) {
  final serialized = isEncoded ? base64Encode(bytes) : utf8.decode(bytes);

  final storage = _browserLocalStorage;
  if (storage != null) {
    storage.setItem(targetId, serialized);
  } else {
    _memoryFallback[targetId] = serialized;
  }
}
