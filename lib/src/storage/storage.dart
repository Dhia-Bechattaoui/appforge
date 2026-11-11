import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/lifecycle.dart';
import '../platform/io_shim.dart';
import 'storage_backend_io.dart'
    if (dart.library.js_interop) 'storage_backend_web.dart';
import 'storage_types.dart';

export 'storage_types.dart';

/// A lightweight, zero-dependency, crash-resilient key-value storage engine.
///
/// Designed from first principles for Flutter applications across mobile,
/// desktop, and web:
/// - **0 ms synchronous reads**: data lives in an in-memory JSON tree.
/// - **Isolation by copy**: collections are deep-copied on write and on read, so
///   mutating a value you read can never silently diverge from what is persisted.
/// - **Fail-fast typing**: only JSON types are accepted. Anything else throws an
///   [ArgumentError] at the `write` call site instead of corrupting later flushes.
/// - **Off-main-thread durability**: on mobile and desktop (`dart:io`), debounced
///   writes are serialized into a single-flight queue that writes and `fsync`s
///   before an atomic rename; on Flutter Web, writes persist via `localStorage`.
/// - **Background flush**: pending changes are persisted synchronously when the
///   OS moves the app to the background (`hidden` / `paused` / `detached`), so a
///   process kill right after a change never loses it.
/// - **Multi-container support**: isolated partitions (e.g. `AppStorage('auth')`).
///
/// **Security boundary:** By default, `AppStorage` writes unencrypted UTF-8 JSON
/// suitable for app preferences, UI state, and non-sensitive local caches. Do
/// not store sensitive PII, auth tokens, or regulated data in plain JSON; pass
/// an [AppStorageCodec] to [AppStorage.init] or use platform secure storage
/// (Keychain/Keystore).
///
/// Example:
/// ```dart
/// await App.initStorage();
/// App.storage.write('onboarded', true);
/// final tags = App.storage.read<List<String>>('tags') ?? const [];
/// App.storage.write('tags', [...tags, 'flutter']);
/// ```
class AppStorage {
  final String containerName;

  String? _targetId;
  Map<String, Object?> _data = <String, Object?>{};
  Timer? _debounceTimer;
  AppStorageCodec? _codec;
  AppStorageErrorHandler? _onError;

  /// Incremented on every mutation.
  int _revision = 0;

  /// Highest revision durably committed to storage.
  int _committedRevision = 0;

  Future<void>? _writeInFlight;
  (Object, StackTrace)? _lastWriteError;
  (Object, StackTrace)? _lastError;
  bool _warnedUninitialized = false;

  final Map<String, List<void Function(dynamic)>> _keyListeners = {};
  final List<void Function()> _allListeners = [];

  static final Map<String, AppStorage> _instances = {};
  static final JsonUtf8Encoder _encoder = JsonUtf8Encoder();
  static const Duration _debounce = Duration(milliseconds: 50);

  AppStorage._(this.containerName);

  /// Returns the singleton [AppStorage] instance for [containerName] (defaults to `'default'`).
  factory AppStorage([String containerName = 'default']) {
    return _instances.putIfAbsent(
      containerName,
      () => AppStorage._(containerName),
    );
  }

  /// Synchronously returns whether the storage container has been initialized.
  bool get isInitialized => _targetId != null;

  /// Whether there are in-memory changes not yet committed to storage.
  bool get hasPendingWrites => _committedRevision < _revision;

  /// Most recent error encountered during initialization, recovery, or persistence,
  /// or `null` if the last operation succeeded.
  Object? get lastError => _lastError?.$1;

  /// Stack trace associated with [lastError], if any.
  StackTrace? get lastErrorStackTrace => _lastError?.$2;

  /// Snapshot of all keys currently stored.
  Iterable<String> get keys => List<String>.unmodifiable(_data.keys);

  /// Snapshot (deep copies) of all values currently stored.
  Iterable<dynamic> get values =>
      List<dynamic>.unmodifiable(_data.values.map(_deepCopy));

  /// Unmodifiable deep copy of the whole container.
  Map<String, dynamic> get toMap =>
      Map<String, dynamic>.unmodifiable(_deepCopy(_data) as Map);

  /// Initializes the storage container.
  ///
  /// Resolution order on `dart:io` platforms:
  /// 1. [path], if non-empty.
  /// 2. [pathResolver], if provided (useful for integrating platform APIs).
  /// 3. [resolveStorageDirectory] (`allowTempFallback: allowTempFallback`).
  ///
  /// On Flutter Web, persists automatically via browser `localStorage` under
  /// `appforge_<container>`.
  ///
  /// Pass [codec] to encrypt/decrypt persisted bytes at rest, [onError] to
  /// observe read/recovery/write failures directly, and [throwOnCorrupt] to
  /// fail fast when persisted JSON or swap recovery fails instead of starting
  /// with an empty map.
  ///
  /// Calling `init` again for the same resolved target is a no-op (updating
  /// [codec] and [onError] if provided). Values written before `init` completes
  /// are merged on top of the persisted data (they are newer) and flushed.
  static Future<AppStorage> init({
    String container = 'default',
    String? path,
    AppStoragePathResolver? pathResolver,
    AppStorageCodec? codec,
    AppStorageErrorHandler? onError,
    bool allowTempFallback = false,
    bool throwOnCorrupt = false,
  }) async {
    final storage = AppStorage(container);
    if (codec != null) storage._codec = codec;
    if (onError != null) storage._onError = onError;

    final resolvedPath = (path != null && path.isNotEmpty)
        ? path
        : (pathResolver != null ? await pathResolver() : null);
    final autoResolve = resolvedPath == null || resolvedPath.isEmpty;
    final targetId = computeStorageTargetId(
      container: container,
      resolvedPath: resolvedPath,
      allowTempFallback: allowTempFallback,
    );

    if (storage._targetId == targetId) return storage;

    final isFirstInit = storage._targetId == null;
    if (!isFirstInit) {
      // Re-targeting to another location: persist pending changes first.
      storage.saveSync();
    }

    if (autoResolve) {
      migrateLegacyStorageIfNeeded(
        container: container,
        targetId: targetId,
        onReport: storage._report,
      );
    }

    final persisted = loadStorageData(
      targetId,
      codec: storage._codec,
      onReport: storage._report,
      throwOnCorrupt: throwOnCorrupt,
    );
    final hasPreInitWrites = isFirstInit && storage._data.isNotEmpty;

    storage._data = <String, Object?>{
      ...persisted,
      if (isFirstInit) ...storage._data,
    };
    storage._targetId = targetId;
    storage._committedRevision = storage._revision;
    _attachLifecycleObserver();

    if (hasPreInitWrites) storage._markDirty();
    return storage;
  }

  /// Synchronously reads a value from memory with 0 ms latency.
  ///
  /// Collections are returned as independent deep copies. Common typed
  /// collections are converted automatically and behave identically before and
  /// after an app restart: `List<String>`, `List<int>`, `List<double>`,
  /// `List<num>`, `List<bool>`, `List<Map<String, dynamic>>`,
  /// `Map<String, String>`, `Map<String, int>`, `Map<String, double>`,
  /// `Map<String, num>`, `Map<String, bool>`.
  ///
  /// Returns [defaultValue] if the key does not exist or the stored value
  /// cannot be represented as [T].
  T? read<T>(String key, {T? defaultValue}) {
    _debugWarnIfUninitialized();
    final stored = _data[key];
    if (stored == null) return defaultValue;

    if (stored is List || stored is Map) {
      final copy = _deepCopy(stored)!;
      if (copy is T) return copy as T;
      return _castCollection<T>(copy) ?? defaultValue;
    }

    if (stored is T) return stored as T;

    // Flexible numeric conversion (e.g. stored double read as int or vice-versa).
    if (T == double && stored is num) return stored.toDouble() as T;
    if (T == int && stored is num) return stored.toInt() as T;

    return defaultValue;
  }

  /// Writes a key-value pair into memory immediately and schedules a debounced,
  /// asynchronous, atomic disk flush.
  ///
  /// Supported types (JSON): `null`, [bool], [num] (finite), [String], [List],
  /// and [Map] with [String] keys, nested arbitrarily. Writing `null` removes
  /// the key. Any other type throws an [ArgumentError] immediately; convert it
  /// first (e.g. `DateTime.toIso8601String()`, `model.toJson()`).
  void write(String key, dynamic value) {
    if (value == null) {
      remove(key);
      return;
    }
    final normalized = _normalize(value, key);
    if (_data.containsKey(key) && _deepEquals(_data[key], normalized)) return;

    _data[key] = normalized;
    _markDirty();
    _notify(key, normalized);
  }

  /// Writes multiple key-value entries at once.
  ///
  /// The batch is validated before anything is applied: if one value is not a
  /// supported type, nothing is written.
  void writeAll(Map<String, dynamic> entries) {
    final normalized = <String, Object?>{
      for (final entry in entries.entries)
        entry.key:
            entry.value == null ? null : _normalize(entry.value, entry.key),
    };

    final changed = <String>[];
    normalized.forEach((key, value) {
      if (value == null) {
        if (_data.remove(key) != null) changed.add(key);
      } else if (!_data.containsKey(key) || !_deepEquals(_data[key], value)) {
        _data[key] = value;
        changed.add(key);
      }
    });
    if (changed.isEmpty) return;

    _markDirty();
    for (final key in changed) {
      _notify(key, _data[key]);
    }
  }

  /// Checks if a key exists in storage.
  bool has(String key) => _data.containsKey(key);

  /// Removes a key from storage.
  void remove(String key) {
    if (!_data.containsKey(key)) return;
    _data.remove(key);
    _markDirty();
    _notify(key, null);
  }

  /// Clears all keys in this storage container.
  ///
  /// Every key listener of a removed key receives `null`; container listeners
  /// are notified once.
  void clear() {
    if (_data.isEmpty) return;
    final removedKeys = _data.keys.toList(growable: false);
    _data.clear();
    _markDirty();

    for (final key in removedKeys) {
      _notifyKey(key, null);
    }
    _notifyContainer();
  }

  /// Subscribes to changes for a specific [key].
  ///
  /// The callback receives an independent copy of the new value (or `null` when
  /// removed). Returns a function that cancels the subscription.
  void Function() listenKey(String key, void Function(dynamic value) callback) {
    _keyListeners.putIfAbsent(key, () => []).add(callback);
    return () => _keyListeners[key]?.remove(callback);
  }

  /// Subscribes to any mutation in this storage container.
  ///
  /// Returns a function that cancels the subscription.
  void Function() listen(void Function() callback) {
    _allListeners.add(callback);
    return () => _allListeners.remove(callback);
  }

  /// Synchronously and durably commits pending changes, bypassing the debounce.
  ///
  /// Blocks the calling isolate on disk I/O; prefer [save] in regular code.
  /// Intended for moments where the process may be suspended immediately
  /// (AppForge already calls it automatically when the app is backgrounded).
  /// No-op when there are no pending changes.
  void saveSync() {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    final targetId = _targetId;
    if (targetId == null || !hasPendingWrites) return;

    final revision = _revision;
    try {
      final bytes = _encodePayload();
      writeStorageSync(targetId, bytes, isEncoded: _codec != null);
      _committedRevision = revision;
      _lastWriteError = null;
      _lastError = null;
    } catch (error, stack) {
      _lastWriteError = (error, stack);
      _report(error, stack, 'while synchronously persisting');
    }
  }

  /// Commits pending changes asynchronously, bypassing the debounce.
  ///
  /// Completes once every change made before the call is durable. Throws the
  /// underlying exception if persistence fails.
  ///
  /// In widget tests (`testWidgets`), real async file I/O only completes inside
  /// `tester.runAsync(...)`; use [saveSync] there instead.
  Future<void> save() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    final target = _revision;
    await _drain();
    final failure = _lastWriteError;
    if (_committedRevision < target && failure != null) {
      Error.throwWithStackTrace(failure.$1, failure.$2);
    }
  }

  // ---------------------------------------------------------------------------
  // Write pipeline
  // ---------------------------------------------------------------------------

  void _markDirty() {
    _revision++;
    if (_targetId == null) return; // merged and flushed by init()
    _attachLifecycleObserver();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      unawaited(_drain());
    });
  }

  /// Single-flight writer: waits for any in-flight write, then writes until the
  /// persisted revision catches up with memory.
  Future<void> _drain() async {
    while (_writeInFlight != null) {
      await _writeInFlight;
    }
    if (!hasPendingWrites || _targetId == null) return;

    final completer = Completer<void>();
    _writeInFlight = completer.future;
    try {
      await _runWrites();
    } finally {
      _writeInFlight = null;
      completer.complete();
    }
  }

  Future<void> _runWrites() async {
    while (hasPendingWrites) {
      final targetId = _targetId;
      if (targetId == null) return;
      final revision = _revision;
      try {
        // Snapshot is encoded synchronously, so later mutations cannot tear it.
        final bytes = _encodePayload();
        await writeStorageAtomic(
          targetId,
          bytes,
          isEncoded: _codec != null,
          shouldCommit: () =>
              revision > _committedRevision && _targetId == targetId,
          onCommitted: () => _committedRevision = revision,
          onReport: _report,
        );
        _lastWriteError = null;
        _lastError = null;
      } catch (error, stack) {
        _lastWriteError = (error, stack);
        _report(error, stack, 'while persisting');
        return; // data stays dirty; retried on the next mutation or save()
      }
    }
  }

  List<int> _encodePayload() {
    final jsonBytes = _encoder.convert(_data);
    final codec = _codec;
    return codec != null ? codec.encode(jsonBytes) : jsonBytes;
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  void _notify(String key, Object? value) {
    _notifyKey(key, value);
    _notifyContainer();
  }

  void _notifyKey(String key, Object? value) {
    final listeners = _keyListeners[key];
    if (listeners == null || listeners.isEmpty) return;
    for (final callback in List.of(listeners)) {
      try {
        callback(_deepCopy(value));
      } catch (error, stack) {
        _report(error, stack, 'while notifying listeners of key "$key"');
      }
    }
  }

  void _notifyContainer() {
    for (final callback in List.of(_allListeners)) {
      try {
        callback();
      } catch (error, stack) {
        _report(error, stack, 'while notifying container listeners');
      }
    }
  }

  void _report(Object error, StackTrace stack, String context) {
    _lastError = (error, stack);
    _onError?.call(error, stack, context);
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'appforge',
      context: ErrorDescription('$context (AppStorage "$containerName")'),
    ));
  }

  void _debugWarnIfUninitialized() {
    if (!kDebugMode || _targetId != null || _warnedUninitialized) return;
    _warnedUninitialized = true;
    debugPrint(
      'AppStorage("$containerName"): read() called before AppStorage.init() '
      'completed. Persisted values are not loaded yet; call '
      '`await App.initStorage()` in main() before runApp().',
    );
  }

  // ---------------------------------------------------------------------------
  // JSON value model
  // ---------------------------------------------------------------------------

  /// Validates [value] as a JSON tree and returns an owned deep copy.
  static Object? _normalize(Object? value, String path) {
    if (value == null || value is bool || value is String) return value;
    if (value is num) {
      if (value.isFinite) return value;
      throw ArgumentError.value(
        value,
        path,
        'AppStorage cannot persist non-finite numbers (NaN / Infinity)',
      );
    }
    if (value is List) {
      return <Object?>[
        for (var i = 0; i < value.length; i++)
          _normalize(value[i], '$path[$i]'),
      ];
    }
    if (value is Map) {
      final out = <String, Object?>{};
      value.forEach((key, entry) {
        if (key is! String) {
          throw ArgumentError.value(
            key,
            '$path{key}',
            'AppStorage map keys must be String',
          );
        }
        out[key] = _normalize(entry, '$path.$key');
      });
      return out;
    }
    throw ArgumentError.value(
      value,
      path,
      'AppStorage supports only JSON types (null, bool, num, String, List, '
      'Map<String, …>). Convert ${value.runtimeType} first, e.g. '
      'DateTime.toIso8601String() or model.toJson()',
    );
  }

  static Object? _deepCopy(Object? value) {
    if (value is List) return <Object?>[for (final e in value) _deepCopy(e)];
    if (value is Map) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key as String: _deepCopy(entry.value),
      };
    }
    return value;
  }

  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final entry in a.entries) {
        if (!b.containsKey(entry.key)) return false;
        if (!_deepEquals(entry.value, b[entry.key])) return false;
      }
      return true;
    }
    if (a is List || a is Map || b is List || b is Map) return false;
    // Distinguish 1 and 1.0 so a type change is persisted.
    return a == b && a.runtimeType == b.runtimeType;
  }

  static T? _castCollection<T>(Object value) {
    if (value is List) {
      if (T == List<String>) {
        return value.every((e) => e is String)
            ? List<String>.from(value) as T
            : null;
      }
      if (T == List<int>) {
        return value.every((e) => e is int) ? List<int>.from(value) as T : null;
      }
      if (T == List<double>) {
        return value.every((e) => e is num)
            ? <double>[for (final e in value) (e as num).toDouble()] as T
            : null;
      }
      if (T == List<num>) {
        return value.every((e) => e is num) ? List<num>.from(value) as T : null;
      }
      if (T == List<bool>) {
        return value.every((e) => e is bool)
            ? List<bool>.from(value) as T
            : null;
      }
      if (T == List<Map<String, dynamic>>) {
        final valid = value.every(
          (e) => e is Map && e.keys.every((k) => k is String),
        );
        return valid
            ? <Map<String, dynamic>>[
                for (final e in value) Map<String, dynamic>.from(e as Map),
              ] as T
            : null;
      }
    } else if (value is Map && value.keys.every((k) => k is String)) {
      if (T == Map<String, String>) {
        return value.values.every((v) => v is String)
            ? Map<String, String>.from(value) as T
            : null;
      }
      if (T == Map<String, int>) {
        return value.values.every((v) => v is int)
            ? Map<String, int>.from(value) as T
            : null;
      }
      if (T == Map<String, double>) {
        return value.values.every((v) => v is num)
            ? <String, double>{
                for (final entry in value.entries)
                  entry.key as String: (entry.value as num).toDouble(),
              } as T
            : null;
      }
      if (T == Map<String, num>) {
        return value.values.every((v) => v is num)
            ? Map<String, num>.from(value) as T
            : null;
      }
      if (T == Map<String, bool>) {
        return value.values.every((v) => v is bool)
            ? Map<String, bool>.from(value) as T
            : null;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Platform directory resolution
  // ---------------------------------------------------------------------------

  /// Pure Dart resolution of the private, persistent application data folder on
  /// `dart:io` platforms.
  ///
  /// Throws a [StateError] if no verified persistent application directory can
  /// be determined on the current platform (unless [allowTempFallback] is
  /// `true`), and throws [UnsupportedError] on Flutter Web.
  static Directory resolveStorageDirectory({bool allowTempFallback = false}) =>
      resolvePlatformStorageDirectory(allowTempFallback: allowTempFallback);

  // ---------------------------------------------------------------------------
  // Lifecycle integration
  // ---------------------------------------------------------------------------

  static bool _lifecycleAttached = false;

  /// Registers a process-wide listener that flushes every container
  /// when the app leaves the foreground. Retried on later writes if the
  /// Flutter [WidgetsBinding] is not initialized yet (e.g. pure Dart CLI tests).
  static void _attachLifecycleObserver() {
    if (_lifecycleAttached) return;
    try {
      AppLifecycleManager.instance.addListener((state) {
        switch (state) {
          case AppLifecycleState.hidden:
          case AppLifecycleState.paused:
          case AppLifecycleState.detached:
            _flushAllPendingSync();
          case AppLifecycleState.resumed:
          case AppLifecycleState.inactive:
            break;
        }
      });
      _lifecycleAttached = true;
    } on FlutterError {
      // WidgetsBinding is not initialized in pure Dart CLI environments.
    }
  }

  static void _flushAllPendingSync() {
    for (final storage in _instances.values) {
      storage.saveSync();
    }
  }

  /// Clears in-memory instances and caches without deleting persisted data,
  /// simulating an application kill and cold restart (pending, uncommitted
  /// changes are lost exactly as they would be in a real kill).
  static void resetMemoryCacheOnly() {
    for (final storage in _instances.values) {
      storage._debounceTimer?.cancel();
    }
    _instances.clear();
  }

  /// Internal reset method for testing teardown.
  static void resetAll() {
    for (final storage in _instances.values) {
      storage._debounceTimer?.cancel();
      storage._data.clear();
      storage._keyListeners.clear();
      storage._allListeners.clear();
      final targetId = storage._targetId;
      if (targetId != null) {
        deleteStorageTarget(targetId, onReport: storage._report);
      }
    }
    _instances.clear();
  }
}
