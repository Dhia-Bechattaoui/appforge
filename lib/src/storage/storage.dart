import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../core/lifecycle.dart';

/// A lightweight, zero-dependency, crash-resilient key-value storage engine.
///
/// Designed from first principles for Flutter mobile applications:
/// - **0 ms synchronous reads**: data lives in an in-memory JSON tree.
/// - **Isolation by copy**: collections are deep-copied on write and on read, so
///   mutating a value you read can never silently diverge from what is on disk.
/// - **Fail-fast typing**: only JSON types are accepted. Anything else throws an
///   [ArgumentError] at the `write` call site instead of corrupting later flushes.
/// - **Off-main-thread durability**: debounced writes are serialized into a
///   single-flight queue that writes and `fsync`s through async `dart:io`, then
///   commits with an atomic rename. The UI isolate never blocks on disk I/O.
/// - **Background flush**: pending changes are persisted synchronously when the
///   OS moves the app to the background (`hidden` / `paused` / `detached`), so a
///   process kill right after a change never loses it.
/// - **Multi-container support**: isolated partitions (e.g. `AppStorage('auth')`).
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

  File? _storageFile;
  Map<String, Object?> _data = <String, Object?>{};
  Timer? _debounceTimer;

  /// Incremented on every mutation.
  int _revision = 0;

  /// Highest revision durably committed to disk.
  int _committedRevision = 0;

  Future<void>? _writeInFlight;
  (Object, StackTrace)? _lastWriteError;
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

  /// Synchronously returns whether the storage container has been initialized from disk.
  bool get isInitialized => _storageFile != null;

  /// Whether there are in-memory changes not yet committed to disk.
  bool get hasPendingWrites => _committedRevision < _revision;

  /// Snapshot of all keys currently stored.
  Iterable<String> get keys => List<String>.unmodifiable(_data.keys);

  /// Snapshot (deep copies) of all values currently stored.
  Iterable<dynamic> get values =>
      List<dynamic>.unmodifiable(_data.values.map(_deepCopy));

  /// Unmodifiable deep copy of the whole container.
  Map<String, dynamic> get toMap =>
      Map<String, dynamic>.unmodifiable(_deepCopy(_data) as Map);

  /// Initializes the storage container on disk.
  ///
  /// If [path] is provided, uses that directory. Otherwise resolves the private,
  /// persistent application directory of the platform:
  /// - **iOS**: `Library/Application Support` (not user-visible, never purged).
  ///   Data from earlier versions stored in `Documents` is migrated automatically.
  /// - **Android**: the app's private data directory.
  ///
  /// Calling `init` again for an already initialized container is a no-op.
  /// Values written before `init` completes are merged on top of the persisted
  /// data (they are newer) and flushed.
  static Future<AppStorage> init({
    String container = 'default',
    String? path,
  }) async {
    final storage = AppStorage(container);
    final autoResolve = path == null || path.isEmpty;
    final baseDir = autoResolve ? resolveStorageDirectory() : Directory(path);

    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }

    final file = File('${baseDir.path}/.appforge_$container.json');
    if (storage._storageFile?.path == file.path) return storage;

    final isFirstInit = storage._storageFile == null;
    if (!isFirstInit) {
      // Re-targeting to another directory: persist pending changes first.
      storage.saveSync();
    }

    if (autoResolve) _migrateLegacyFile(container, file);

    final persisted = _load(file);
    final hasPreInitWrites = isFirstInit && storage._data.isNotEmpty;

    storage._data = <String, Object?>{
      ...persisted,
      if (isFirstInit) ...storage._data,
    };
    storage._storageFile = file;
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

    final file = _storageFile;
    if (file == null || !hasPendingWrites) return;

    final revision = _revision;
    final tmp = File('${file.path}.sync.tmp');
    try {
      final bytes = _encoder.convert(_data);
      final raf = tmp.openSync(mode: FileMode.write);
      try {
        raf.writeFromSync(bytes);
        raf.flushSync();
      } finally {
        raf.closeSync();
      }
      tmp.renameSync(file.path);
      _committedRevision = revision;
      _lastWriteError = null;
    } catch (error, stack) {
      _lastWriteError = (error, stack);
      _report(error, stack, 'while synchronously persisting');
    }
  }

  /// Commits pending changes to disk asynchronously, bypassing the debounce.
  ///
  /// Completes once every change made before the call is durable. Throws the
  /// underlying [FileSystemException] if the disk write fails.
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
    if (_storageFile == null) return; // merged and flushed by init()
    _attachLifecycleObserver();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _debounceTimer = null;
      unawaited(_drain());
    });
  }

  /// Single-flight writer: waits for any in-flight write, then writes until the
  /// on-disk revision catches up with memory.
  Future<void> _drain() async {
    while (_writeInFlight != null) {
      await _writeInFlight;
    }
    if (!hasPendingWrites || _storageFile == null) return;

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
      final file = _storageFile;
      if (file == null) return;
      final revision = _revision;
      try {
        // Snapshot is encoded synchronously, so later mutations cannot tear it.
        final bytes = _encoder.convert(_data);
        await _writeAtomic(file, bytes, revision);
        _lastWriteError = null;
      } catch (error, stack) {
        _lastWriteError = (error, stack);
        _report(error, stack, 'while persisting');
        return; // data stays dirty; retried on the next mutation or save()
      }
    }
  }

  Future<void> _writeAtomic(File file, List<int> bytes, int revision) async {
    final tmp = File('${file.path}.tmp');
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush(); // fsync: bytes are on stable storage before the swap
    } finally {
      await raf.close();
    }

    // Commit point. Performed synchronously so it is atomic with respect to
    // saveSync() on this isolate: an older snapshot can never replace a newer one.
    if (revision > _committedRevision && _storageFile?.path == file.path) {
      tmp.renameSync(file.path);
      _committedRevision = revision;
    } else {
      _deleteQuietly(tmp);
    }
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
    FlutterError.reportError(FlutterErrorDetails(
      exception: error,
      stack: stack,
      library: 'appforge',
      context: ErrorDescription('$context (AppStorage "$containerName")'),
    ));
  }

  void _debugWarnIfUninitialized() {
    if (!kDebugMode || _storageFile != null || _warnedUninitialized) return;
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
    try {
      if (value is List) {
        if (T == List<String>) return List<String>.from(value) as T;
        if (T == List<int>) return List<int>.from(value) as T;
        if (T == List<double>) {
          return <double>[for (final e in value) (e as num).toDouble()] as T;
        }
        if (T == List<num>) return List<num>.from(value) as T;
        if (T == List<bool>) return List<bool>.from(value) as T;
        if (T == List<Map<String, dynamic>>) {
          return <Map<String, dynamic>>[
            for (final e in value) Map<String, dynamic>.from(e as Map),
          ] as T;
        }
      } else if (value is Map) {
        if (T == Map<String, String>) {
          return Map<String, String>.from(value) as T;
        }
        if (T == Map<String, int>) return Map<String, int>.from(value) as T;
        if (T == Map<String, double>) {
          return <String, double>{
            for (final entry in value.entries)
              entry.key as String: (entry.value as num).toDouble(),
          } as T;
        }
        if (T == Map<String, num>) return Map<String, num>.from(value) as T;
        if (T == Map<String, bool>) return Map<String, bool>.from(value) as T;
      }
    } catch (_) {
      // Element types do not match T: caller falls back to defaultValue.
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Disk loading & platform paths
  // ---------------------------------------------------------------------------

  /// Loads the committed file; if missing or corrupt, recovers the newest
  /// intact swap file left by an interrupted write.
  static Map<String, Object?> _load(File file) {
    final swaps = [File('${file.path}.tmp'), File('${file.path}.sync.tmp')];

    final committed = _tryDecode(file);
    if (committed != null) {
      swaps.forEach(_deleteQuietly);
      return committed;
    }

    final intact = <(File, Map<String, Object?>)>[];
    for (final swap in swaps) {
      final decoded = _tryDecode(swap);
      if (decoded != null) intact.add((swap, decoded));
    }
    if (intact.isEmpty) return <String, Object?>{};

    intact.sort(
        (a, b) => b.$1.lastModifiedSync().compareTo(a.$1.lastModifiedSync()));
    final (newest, data) = intact.first;
    try {
      newest.renameSync(file.path);
    } catch (_) {}
    swaps.forEach(_deleteQuietly);
    return data;
  }

  static Map<String, Object?>? _tryDecode(File file) {
    try {
      if (!file.existsSync()) return null;
      final content = file.readAsStringSync();
      if (content.trim().isEmpty) return null;
      final decoded = json.decode(content);
      return decoded is Map ? Map<String, Object?>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Moves data written by earlier AppForge versions to the current location.
  static void _migrateLegacyFile(String container, File target) {
    if (target.existsSync()) return;
    try {
      if (!Platform.isIOS) return;
      final appRoot = Directory.systemTemp.parent.path;
      final legacy = File('$appRoot/Documents/.appforge_$container.json');
      if (legacy.existsSync()) legacy.renameSync(target.path);
    } catch (_) {}
  }

  /// Pure Dart resolution of the private, persistent application data folder.
  static Directory resolveStorageDirectory() {
    try {
      final appRoot = Directory.systemTemp.parent.path;
      if (Platform.isIOS) {
        // Apple's designated location for app-managed data files: hidden from
        // the Files app and never purged by the OS (unlike tmp/ and Caches/).
        return Directory('$appRoot/Library/Application Support');
      } else if (Platform.isAndroid) {
        final appFlutter = Directory('$appRoot/app_flutter');
        if (appFlutter.existsSync()) return appFlutter;
        final files = Directory('$appRoot/files');
        if (files.existsSync()) return files;
      }
    } catch (_) {}

    // Fallback for desktop development and test environments.
    return Directory('${Directory.systemTemp.path}/appforge_data');
  }

  // ---------------------------------------------------------------------------
  // Lifecycle integration
  // ---------------------------------------------------------------------------

  static bool _lifecycleAttached = false;

  /// Registers a process-wide listener that flushes every container
  /// when the app leaves the foreground. Silently retried later if the Flutter
  /// binding is not initialized yet.
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
    } catch (_) {
      // Binding might not be available yet in pure CLI/Dart test environments.
    }
  }

  static void _flushAllPendingSync() {
    for (final storage in _instances.values) {
      storage.saveSync();
    }
  }

  /// Clears in-memory instances and caches without deleting disk files,
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
      final file = storage._storageFile;
      if (file != null) {
        _deleteQuietly(file);
        _deleteQuietly(File('${file.path}.tmp'));
        _deleteQuietly(File('${file.path}.sync.tmp'));
      }
    }
    _instances.clear();
  }
}
