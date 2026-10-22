import 'dart:async';
import 'dart:collection';

/// Eviction policy algorithm used when cache capacity is exceeded.
enum CacheEvictionPolicy {
  /// Least Recently Used: discards items accessed longest ago.
  lru,

  /// Least Frequently Used: discards items accessed fewest times.
  lfu,

  /// First In, First Out: discards items in insertion order.
  fifo,
}

/// Statistics and performance metrics for a cache bucket.
class CacheStats {
  /// Number of successful lookups finding a fresh entry.
  final int hits;

  /// Number of lookups finding no entry or an expired entry.
  final int misses;

  /// Number of entries evicted due to capacity constraints.
  final int evictions;

  /// Number of entries removed due to TTL expiration.
  final int expirations;

  /// Number of active items currently in memory.
  final int size;

  /// Maximum entry capacity of this bucket.
  final int capacity;

  const CacheStats({
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.expirations,
    required this.size,
    required this.capacity,
  });

  /// Total number of lookup requests (hits + misses).
  int get totalRequests => hits + misses;

  /// Cache hit ratio as a fraction between 0.0 and 1.0 (0% to 100%).
  double get hitRate => totalRequests == 0 ? 0.0 : hits / totalRequests;

  @override
  String toString() {
    final ratePercent = (hitRate * 100).toStringAsFixed(1);
    return 'CacheStats(size: $size/$capacity, hits: $hits, misses: $misses, hitRate: $ratePercent%, evictions: $evictions, expirations: $expirations)';
  }
}

/// A stored in-memory cache entry with access metrics and TTL tracking.
class CacheEntry<T> {
  /// Stored payload value.
  final T value;

  /// Monotonic microsecond timestamp when this entry was created.
  final int createdAtMicros;

  /// Monotonic microsecond timestamp when this entry was last accessed.
  int lastAccessedAtMicros;

  /// Total number of times this entry has been accessed.
  int accessCount;

  /// Time-To-Live duration. If null, this entry never expires based on time.
  final Duration? ttl;

  CacheEntry({
    required this.value,
    int? createdAtMicros,
    int? lastAccessedAtMicros,
    this.accessCount = 0,
    this.ttl,
  })  : createdAtMicros = createdAtMicros ?? AppCacheBucket.monotonicNowMicros,
        lastAccessedAtMicros = lastAccessedAtMicros ??
            (createdAtMicros ?? AppCacheBucket.monotonicNowMicros);

  /// Whether this entry has exceeded its time-to-live expiration.
  bool get isExpired {
    if (ttl == null) return false;
    return (AppCacheBucket.monotonicNowMicros - createdAtMicros) >
        ttl!.inMicroseconds;
  }

  /// Timestamp when this entry was created (relative to system clock).
  DateTime get createdAt => DateTime.now().subtract(
        Duration(
          microseconds: AppCacheBucket.monotonicNowMicros - createdAtMicros,
        ),
      );

  /// Timestamp when this entry was last accessed (relative to system clock).
  DateTime get lastAccessedAt => DateTime.now().subtract(
        Duration(
          microseconds:
              AppCacheBucket.monotonicNowMicros - lastAccessedAtMicros,
        ),
      );

  set lastAccessedAt(DateTime dt) {
    lastAccessedAtMicros = AppCacheBucket.monotonicNowMicros;
  }
}

/// An isolated, in-memory cache container with configurable eviction policies and capacity.
class AppCacheBucket {
  static final Stopwatch _monotonicClock = Stopwatch()..start();

  /// Monotonic microsecond timestamp independent of system wall-clock / NTP changes.
  static int get monotonicNowMicros => _monotonicClock.elapsedMicroseconds;

  /// Identifier name of this bucket.
  final String name;

  /// Maximum number of active entries allowed in memory.
  final int maxEntries;

  /// Default Time-To-Live for entries in this bucket.
  final Duration? defaultTtl;

  /// Eviction algorithm applied when [maxEntries] is reached.
  final CacheEvictionPolicy evictionPolicy;

  final LinkedHashMap<String, CacheEntry<dynamic>> _entries =
      LinkedHashMap<String, CacheEntry<dynamic>>();

  final Map<String, Future<dynamic>> _inflightFetches = {};

  int _generation = 0;
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;

  AppCacheBucket({
    required this.name,
    this.maxEntries = 100,
    this.defaultTtl,
    this.evictionPolicy = CacheEvictionPolicy.lru,
  }) : assert(maxEntries > 0, 'maxEntries must be greater than zero');

  /// Current number of stored entries in memory.
  int get size => _entries.length;

  /// Whether this cache bucket is empty.
  bool get isEmpty => _entries.isEmpty;

  /// Whether this cache bucket contains any entries.
  bool get isNotEmpty => _entries.isNotEmpty;

  CacheEntry<dynamic>? _peekFreshEntry(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.isExpired) {
      _entries.remove(key);
      _expirations++;
      return null;
    }
    return entry;
  }

  void _recordHit(String key, CacheEntry<dynamic> entry) {
    _hits++;
    entry.accessCount++;
    entry.lastAccessedAtMicros = monotonicNowMicros;

    // In LRU, re-insert to move this key to the end of insertion-ordered map
    if (evictionPolicy == CacheEvictionPolicy.lru) {
      _entries.remove(key);
      _entries[key] = entry;
    }
  }

  /// Retrieves an unexpired entry from cache, or null if missing or expired.
  T? get<T>(String key) {
    final entry = _peekFreshEntry(key);

    if (entry == null) {
      _misses++;
      return null;
    }

    _recordHit(key, entry);
    return entry.value as T?;
  }

  /// Stores a [value] in cache under [key] with optional per-entry [ttl].
  void set<T>(String key, T value, {Duration? ttl}) {
    final effectiveTtl = ttl ?? defaultTtl;

    if (_entries.containsKey(key)) {
      _entries.remove(key);
    } else if (_entries.length >= maxEntries) {
      _evictOne();
    }

    _entries[key] = CacheEntry<T>(
      value: value,
      ttl: effectiveTtl,
    );
  }

  /// Retrieves an existing unexpired value, or atomically executes [fetcher]
  /// and caches the result with single-flight request coalescing.
  Future<T> getOrFetch<T>(
    String key,
    FutureOr<T> Function() fetcher, {
    Duration? ttl,
  }) async {
    final freshEntry = _peekFreshEntry(key);
    if (freshEntry != null) {
      _recordHit(key, freshEntry);
      return freshEntry.value as T;
    }

    // Single-flight coalescing: If a fetch is already running for this key, await it
    if (_inflightFetches.containsKey(key)) {
      _hits++; // Coalesced request: counts as a hit saving a redundant backend call
      final inFlight = await _inflightFetches[key]!;
      return inFlight as T;
    }

    _misses++;
    final completer = Completer<T>();
    completer.future.ignore();
    _inflightFetches[key] = completer.future;
    final int captureGen = _generation;

    try {
      final result = await fetcher();
      if (_generation == captureGen) {
        set<T>(key, result, ttl: ttl);
      }
      completer.complete(result);
      return result;
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      rethrow;
    } finally {
      if (_inflightFetches[key] == completer.future) {
        _inflightFetches.remove(key);
      }
    }
  }

  /// Returns true if [key] exists and has not expired.
  bool has(String key) {
    return _peekFreshEntry(key) != null;
  }

  /// Invalidates and removes [key] from the cache. Returns true if key was present.
  bool invalidate(String key) {
    _inflightFetches.remove(key);
    final removed = _entries.remove(key);
    return removed != null;
  }

  /// Invalidates and removes all entries satisfying [predicate].
  /// Returns the count of removed items.
  int invalidateWhere(bool Function(String key, dynamic value) predicate) {
    final keysToRemove = <String>[];
    for (final entry in _entries.entries) {
      if (predicate(entry.key, entry.value.value)) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _entries.remove(key);
      _inflightFetches.remove(key);
    }
    return keysToRemove.length;
  }

  /// Prunes all expired items from memory immediately. Returns count of purged items.
  int pruneExpired() {
    final expiredKeys = <String>[];
    for (final entry in _entries.entries) {
      if (entry.value.isExpired) {
        expiredKeys.add(entry.key);
      }
    }
    for (final key in expiredKeys) {
      _entries.remove(key);
    }
    _expirations += expiredKeys.length;
    return expiredKeys.length;
  }

  /// Purges all cached entries in this bucket and cancels in-flight fetches.
  void clear() {
    _generation++;
    _entries.clear();
    _inflightFetches.clear();
  }

  /// Snapshot of current cache metrics.
  CacheStats get stats => CacheStats(
        hits: _hits,
        misses: _misses,
        evictions: _evictions,
        expirations: _expirations,
        size: _entries.length,
        capacity: maxEntries,
      );

  /// Resets statistical metrics to zero.
  void resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
  }

  void _evictOne() {
    if (_entries.isEmpty) return;

    // First try pruning expired items to free capacity without evicting fresh items
    if (pruneExpired() > 0) return;

    String? victimKey;

    switch (evictionPolicy) {
      case CacheEvictionPolicy.fifo:
        victimKey = _entries.keys.first;
        break;

      case CacheEvictionPolicy.lru:
        // LinkedHashMap keeps least recently accessed at the head
        victimKey = _entries.keys.first;
        break;

      case CacheEvictionPolicy.lfu:
        int minAccess = 999999999;
        int oldestAccessMicros = monotonicNowMicros;

        for (final entry in _entries.entries) {
          final count = entry.value.accessCount;
          final accessed = entry.value.lastAccessedAtMicros;

          if (count < minAccess ||
              (count == minAccess && accessed < oldestAccessMicros)) {
            minAccess = count;
            oldestAccessMicros = accessed;
            victimKey = entry.key;
          }
        }
        break;
    }

    if (victimKey != null) {
      _entries.remove(victimKey);
      _evictions++;
    }
  }
}

/// High-performance, zero-dependency in-memory cache engine for Flutter.
///
/// Supports hardware-accelerated memory access, LRU/LFU/FIFO eviction,
/// Time-To-Live (TTL) expiration, single-flight request coalescing, and named buckets.
///
/// ```dart
/// // Simple get & set
/// AppCache.set('user_123', userData, ttl: const Duration(minutes: 10));
/// final user = AppCache.get<User>('user_123');
///
/// // Atomic Cache-Aside with request coalescing:
/// final profile = await AppCache.getOrFetch(
///   'profile_$id',
///   () => api.fetchProfile(id),
///   ttl: const Duration(minutes: 5),
/// );
///
/// // Isolated Named Buckets:
/// final searchCache = AppCache.bucket('search_queries', maxEntries: 50);
/// searchCache.set('query_flutter', results);
/// ```
abstract class AppCache {
  static final Map<String, AppCacheBucket> _buckets = {};

  static final AppCacheBucket _defaultBucket = AppCacheBucket(
    name: 'default',
    maxEntries: 100,
    evictionPolicy: CacheEvictionPolicy.lru,
  );

  /// The root default cache bucket.
  static AppCacheBucket get defaultBucket => _defaultBucket;

  /// Retrieves or initializes an isolated named cache bucket.
  static AppCacheBucket bucket(
    String name, {
    int maxEntries = 100,
    Duration? defaultTtl,
    CacheEvictionPolicy evictionPolicy = CacheEvictionPolicy.lru,
  }) {
    return _buckets.putIfAbsent(
      name,
      () => AppCacheBucket(
        name: name,
        maxEntries: maxEntries,
        defaultTtl: defaultTtl,
        evictionPolicy: evictionPolicy,
      ),
    );
  }

  /// Retrieves an unexpired value from the default cache.
  static T? get<T>(String key) => _defaultBucket.get<T>(key);

  /// Stores a [value] in the default cache under [key] with optional [ttl].
  static void set<T>(String key, T value, {Duration? ttl}) =>
      _defaultBucket.set<T>(key, value, ttl: ttl);

  /// Retrieves a value or executes [fetcher] and caches the result.
  static Future<T> getOrFetch<T>(
    String key,
    FutureOr<T> Function() fetcher, {
    Duration? ttl,
  }) =>
      _defaultBucket.getOrFetch<T>(key, fetcher, ttl: ttl);

  /// Checks if [key] exists and is fresh in the default cache.
  static bool has(String key) => _defaultBucket.has(key);

  /// Removes [key] from the default cache.
  static bool invalidate(String key) => _defaultBucket.invalidate(key);

  /// Invalidates entries matching [predicate] from default cache.
  static int invalidateWhere(
          bool Function(String key, dynamic value) predicate) =>
      _defaultBucket.invalidateWhere(predicate);

  /// Prunes all expired entries across the default cache.
  static int pruneExpired() => _defaultBucket.pruneExpired();

  /// Clears all entries from the default cache.
  static void clear() => _defaultBucket.clear();

  /// Statistics for the default cache bucket.
  static CacheStats get stats => _defaultBucket.stats;

  /// Resets all named buckets and clears default cache.
  static void resetAll() {
    _defaultBucket.clear();
    _defaultBucket.resetStats();
    for (final bucket in _buckets.values) {
      bucket.clear();
      bucket.resetStats();
    }
    _buckets.clear();
  }
}
