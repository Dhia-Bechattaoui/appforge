import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  setUp(() {
    AppCache.resetAll();
  });

  group('AppCache - Basic Storage & Retrieval', () {
    test('stores and retrieves typed values correctly', () {
      AppCache.set('user_name', 'Dhia');
      AppCache.set('user_age', 30);
      AppCache.set('is_active', true);

      expect(AppCache.get<String>('user_name'), equals('Dhia'));
      expect(AppCache.get<int>('user_age'), equals(30));
      expect(AppCache.get<bool>('is_active'), isTrue);
      expect(AppCache.get<String>('non_existent'), isNull);
    });

    test('has() checks existence and fresh status', () {
      expect(AppCache.has('key1'), isFalse);
      AppCache.set('key1', 'value1');
      expect(AppCache.has('key1'), isTrue);
    });

    test('invalidate() removes a specific entry', () {
      AppCache.set('temp', 123);
      expect(AppCache.has('temp'), isTrue);

      final removed = AppCache.invalidate('temp');
      expect(removed, isTrue);
      expect(AppCache.has('temp'), isFalse);
      expect(AppCache.get<int>('temp'), isNull);

      final removeAgain = AppCache.invalidate('temp');
      expect(removeAgain, isFalse);
    });

    test('clear() flushes all entries in bucket', () {
      AppCache.set('a', 1);
      AppCache.set('b', 2);
      expect(AppCache.stats.size, equals(2));

      AppCache.clear();
      expect(AppCache.stats.size, equals(0));
      expect(AppCache.get<int>('a'), isNull);
      expect(AppCache.get<int>('b'), isNull);
    });

    test('invalidateWhere() purges matching entries', () {
      AppCache.set('post_1', {'type': 'text', 'id': 1});
      AppCache.set('post_2', {'type': 'video', 'id': 2});
      AppCache.set('post_3', {'type': 'text', 'id': 3});

      final removedCount = AppCache.invalidateWhere(
        (key, value) => (value as Map)['type'] == 'text',
      );

      expect(removedCount, equals(2));
      expect(AppCache.has('post_1'), isFalse);
      expect(AppCache.has('post_2'), isTrue);
      expect(AppCache.has('post_3'), isFalse);
    });
  });

  group('AppCache - Request Coalescing (Single-Flight)', () {
    test('returns cached value without calling fetcher', () async {
      AppCache.set('cached_key', 'initial_value');
      var callCount = 0;

      final result = await AppCache.getOrFetch<String>(
        'cached_key',
        () async {
          callCount++;
          return 'new_value';
        },
      );

      expect(result, equals('initial_value'));
      expect(callCount, equals(0));
    });

    test('executes fetcher and caches result when missing', () async {
      var callCount = 0;
      final result = await AppCache.getOrFetch<int>(
        'computed_sum',
        () async {
          callCount++;
          return 42;
        },
      );

      expect(result, equals(42));
      expect(callCount, equals(1));
      expect(AppCache.get<int>('computed_sum'), equals(42));
    });

    test('coalesces concurrent requests to a single execution', () async {
      var networkCallCount = 0;

      Future<String> slowFetch() async {
        networkCallCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'network_response';
      }

      // Launch 5 concurrent calls for the exact same key
      final futures = List.generate(
        5,
        (_) => AppCache.getOrFetch<String>('heavy_query', slowFetch),
      );

      final results = await Future.wait(futures);

      expect(results, equals(List.filled(5, 'network_response')));
      expect(networkCallCount, equals(1));
      expect(AppCache.get<String>('heavy_query'), equals('network_response'));
      expect(AppCache.stats.misses, equals(1));
      expect(AppCache.stats.hits,
          equals(5)); // 4 coalesced hits + 1 hit from get above
    });

    test('propagates fetcher errors and cleans up in-flight state', () async {
      var callCount = 0;

      await expectLater(
        AppCache.getOrFetch<String>(
          'failing_key',
          () async {
            callCount++;
            throw StateError('Network timeout');
          },
        ),
        throwsA(isA<StateError>()),
      );

      expect(callCount, equals(1));
      expect(AppCache.has('failing_key'), isFalse);

      // Subsequent attempt after error can succeed
      final recovered = await AppCache.getOrFetch<String>(
        'failing_key',
        () async => 'recovered',
      );
      expect(recovered, equals('recovered'));
    });
  });

  group('AppCache - Time-To-Live (TTL) & Expiration', () {
    test('expires lazily after TTL duration', () async {
      AppCache.set(
        'short_lived',
        'hello',
        ttl: const Duration(milliseconds: 30),
      );

      expect(AppCache.get<String>('short_lived'), equals('hello'));
      expect(AppCache.has('short_lived'), isTrue);

      await Future.delayed(const Duration(milliseconds: 40));

      expect(AppCache.has('short_lived'), isFalse);
      expect(AppCache.get<String>('short_lived'), isNull);
      expect(AppCache.stats.expirations, equals(1));
    });

    test('pruneExpired() proactively purges expired entries', () async {
      final bucket = AppCache.bucket('ttl_bucket',
          defaultTtl: const Duration(milliseconds: 30));

      bucket.set('item1', 'val1');
      bucket.set('item2', 'val2');
      bucket.set('item3', 'val3',
          ttl: const Duration(seconds: 10)); // unexpired

      expect(bucket.size, equals(3));

      await Future.delayed(const Duration(milliseconds: 40));

      final pruned = bucket.pruneExpired();
      expect(pruned, equals(2));
      expect(bucket.size, equals(1));
      expect(bucket.has('item1'), isFalse);
      expect(bucket.has('item2'), isFalse);
      expect(bucket.has('item3'), isTrue);
    });
  });

  group('AppCache - Eviction Policies', () {
    test('LRU: evicts least recently accessed entry', () {
      final bucket = AppCache.bucket(
        'lru_test',
        maxEntries: 3,
        evictionPolicy: CacheEvictionPolicy.lru,
      );

      bucket.set('a', 1);
      bucket.set('b', 2);
      bucket.set('c', 3);

      // Access 'a' to mark it as recently used
      expect(bucket.get<int>('a'), equals(1));

      // Adding 'd' should evict 'b' (since 'b' is now least recently accessed)
      bucket.set('d', 4);

      expect(bucket.has('a'), isTrue);
      expect(bucket.has('b'), isFalse);
      expect(bucket.has('c'), isTrue);
      expect(bucket.has('d'), isTrue);
      expect(bucket.stats.evictions, equals(1));
    });

    test('LFU: evicts least frequently accessed entry', () {
      final bucket = AppCache.bucket(
        'lfu_test',
        maxEntries: 3,
        evictionPolicy: CacheEvictionPolicy.lfu,
      );

      bucket.set('a', 1);
      bucket.set('b', 2);
      bucket.set('c', 3);

      // Access 'a' 3 times, 'c' 1 time, 'b' 0 times
      bucket.get<int>('a');
      bucket.get<int>('a');
      bucket.get<int>('a');
      bucket.get<int>('c');

      // Adding 'd' should evict 'b' because it has 0 accesses
      bucket.set('d', 4);

      expect(bucket.has('a'), isTrue);
      expect(bucket.has('b'), isFalse);
      expect(bucket.has('c'), isTrue);
      expect(bucket.has('d'), isTrue);
      expect(bucket.stats.evictions, equals(1));
    });

    test('FIFO: evicts oldest inserted entry regardless of access count', () {
      final bucket = AppCache.bucket(
        'fifo_test',
        maxEntries: 3,
        evictionPolicy: CacheEvictionPolicy.fifo,
      );

      bucket.set('first', 1);
      bucket.set('second', 2);
      bucket.set('third', 3);

      // Access 'first' multiple times
      bucket.get<int>('first');
      bucket.get<int>('first');

      // Adding 'fourth' must evict 'first' because it was inserted first
      bucket.set('fourth', 4);

      expect(bucket.has('first'), isFalse);
      expect(bucket.has('second'), isTrue);
      expect(bucket.has('third'), isTrue);
      expect(bucket.has('fourth'), isTrue);
      expect(bucket.stats.evictions, equals(1));
    });

    test('eviction prioritizes expired entries over valid entries', () async {
      final bucket = AppCache.bucket(
        'priority_evict',
        maxEntries: 2,
        evictionPolicy: CacheEvictionPolicy.lru,
      );

      bucket.set('stale', 'old', ttl: const Duration(milliseconds: 20));
      bucket.set('fresh', 'stay');

      await Future.delayed(const Duration(milliseconds: 30));

      // Capacity is 2. 'stale' is expired. Adding 'new_item' should purge 'stale'
      // instead of evicting 'fresh'
      bucket.set('new_item', 'value');

      expect(bucket.has('stale'), isFalse);
      expect(bucket.has('fresh'), isTrue);
      expect(bucket.has('new_item'), isTrue);
      // Eviction count should be 0 because it was pruned as expired
      expect(bucket.stats.evictions, equals(0));
      expect(bucket.stats.expirations, equals(1));
    });
  });

  group('AppCache - Metrics & Performance Stats', () {
    test('calculates hitRate and counts accurately', () {
      final bucket = AppCache.bucket('stats_bucket', maxEntries: 10);

      bucket.set('k1', 'v1');

      // 2 hits
      bucket.get<String>('k1');
      bucket.get<String>('k1');

      // 2 misses
      bucket.get<String>('missing_1');
      bucket.get<String>('missing_2');

      final stats = bucket.stats;
      expect(stats.hits, equals(2));
      expect(stats.misses, equals(2));
      expect(stats.totalRequests, equals(4));
      expect(stats.hitRate, equals(0.5));
      expect(stats.toString(), contains('hitRate: 50.0%'));

      bucket.resetStats();
      expect(bucket.stats.hits, equals(0));
      expect(bucket.stats.misses, equals(0));
      expect(bucket.stats.hitRate, equals(0.0));
    });
  });

  group('AppCache - App Facade Integration', () {
    test('App.cache forwards to defaultBucket', () {
      App.cache.set('via_app', 999);
      expect(App.cache.get<int>('via_app'), equals(999));
      expect(AppCache.get<int>('via_app'), equals(999));
    });

    test('App.cacheBucket initializes named buckets', () {
      final userBucket = App.cacheBucket(
        'users',
        maxEntries: 50,
        evictionPolicy: CacheEvictionPolicy.lru,
      );

      userBucket.set('user_1', 'Alice');
      expect(userBucket.get<String>('user_1'), equals('Alice'));
      expect(AppCache.get<String>('user_1'), isNull);
    });

    test(
        'In-flight fetch initiated before clear() does not resurrect into cleared cache',
        () async {
      final bucket = AppCache.bucket('generation_test');
      final completer = Completer<String>();

      // Launch slow fetch
      final fetchFuture =
          bucket.getOrFetch<String>('slow_key', () => completer.future);

      // Cache is cleared while fetch is in-flight
      bucket.clear();
      expect(bucket.stats.size, 0);

      // Now complete the slow fetch
      completer.complete('stale_payload');
      final result = await fetchFuture;

      expect(result, 'stale_payload');
      // The cleared bucket must NOT contain the stale entry
      expect(bucket.has('slow_key'), isFalse);
      expect(bucket.get<String>('slow_key'), isNull);
      expect(bucket.stats.size, 0);
    });
  });
}
