import 'dart:async';

/// Byte-level codec used by `AppStorage` to transform persisted payloads at rest.
///
/// Implement this interface to apply application-level encryption (for example,
/// AES-GCM backed by OS Keychain/Keystore) without adding third-party package
/// dependencies to AppForge.
abstract class AppStorageCodec {
  const AppStorageCodec();

  /// Transforms serialized UTF-8 JSON [bytes] before they are written to disk.
  List<int> encode(List<int> bytes);

  /// Reverses [encode] when reading persisted bytes back from disk.
  List<int> decode(List<int> bytes);
}

/// Callback invoked whenever `AppStorage` encounters a read, recovery,
/// migration, or persistence failure.
typedef AppStorageErrorHandler = void Function(
  Object error,
  StackTrace stackTrace,
  String context,
);

/// Asynchronous or synchronous callback returning the directory path where
/// `AppStorage` should persist container files.
typedef AppStoragePathResolver = FutureOr<String> Function();

/// Internal reporting callback passed into platform storage backends.
typedef StorageBackendReporter = void Function(
  Object error,
  StackTrace stackTrace,
  String context,
);
