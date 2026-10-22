import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('Step 11: Zero-Dependency AppStorage Engine', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('appforge_storage_test_');
      AppStorage.resetAll();
    });

    tearDown(() {
      AppStorage.resetAll();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('0ms Synchronous Reads & Writes for Primitives, Lists, and Maps',
        () async {
      final storage =
          await AppStorage.init(container: 'test_box', path: tempDir.path);

      // Writes in memory
      storage.write('username', 'dhia');
      storage.write('age', 28);
      storage.write('score', 99.5);
      storage.write('is_active', true);
      storage.write('tags', ['flutter', 'zero_dep']);
      storage.write('meta', {'role': 'lead'});

      // Synchronous instant reads
      expect(storage.read<String>('username'), 'dhia');
      expect(storage.read<int>('age'), 28);
      expect(storage.read<double>('score'), 99.5);
      expect(storage.read<bool>('is_active'), true);
      expect(storage.read<List>('tags'), ['flutter', 'zero_dep']);
      expect(storage.read<Map>('meta')!['role'], 'lead');

      // Default values
      expect(storage.read<String>('missing', defaultValue: 'guest'), 'guest');
      expect(storage.has('username'), true);
      expect(storage.has('missing'), false);
    });

    test('Atomic POSIX Swap flushes data to disk crash-safely', () async {
      final storage =
          await AppStorage.init(container: 'atomic_box', path: tempDir.path);

      storage.write('token', 'secret_jwt_xyz');
      // Save forces immediate atomic flush
      await storage.save();

      final storageFile = File('${tempDir.path}/.appforge_atomic_box.json');
      expect(storageFile.existsSync(), true);
      expect(storageFile.readAsStringSync().contains('secret_jwt_xyz'), true);

      // Verify no orphan .tmp file remains
      final tmpFile = File('${storageFile.path}.tmp');
      expect(tmpFile.existsSync(), false);
    });

    test('Interrupted write recovery: restores from intact .tmp swap file',
        () async {
      final storageFile = File('${tempDir.path}/.appforge_interrupted.json');
      final tmpFile = File('${storageFile.path}.tmp');

      // Simulate corrupted/empty target file and intact .tmp file
      storageFile.writeAsStringSync('{corrupted_json_content');
      tmpFile.writeAsStringSync('{"recovered_key": "safe_value"}');

      // AppStorage init should automatically recover data from the swap file
      final storage = await AppStorage.init(
        container: 'interrupted',
        path: tempDir.path,
      );

      expect(storage.read<String>('recovered_key'), 'safe_value');
      expect(tmpFile.existsSync(), false);
      expect(storageFile.existsSync(), true);
    });

    test('Named container isolation', () async {
      final authBox =
          await AppStorage.init(container: 'auth', path: tempDir.path);
      final cacheBox =
          await AppStorage.init(container: 'cache', path: tempDir.path);

      authBox.write('user_id', '101');
      cacheBox.write('user_id', '999');

      expect(authBox.read<String>('user_id'), '101');
      expect(cacheBox.read<String>('user_id'), '999');
    });

    test('Reactive key listeners and global change listeners', () async {
      final storage =
          await AppStorage.init(container: 'listener_box', path: tempDir.path);

      final tokenEvents = <dynamic>[];
      int allCount = 0;

      final cancelKey = storage.listenKey('token', (val) {
        tokenEvents.add(val);
      });
      final cancelAll = storage.listen(() {
        allCount++;
      });

      storage.write('token', 'abc');
      storage.write('other', 123);
      storage.write('token', 'def');

      expect(tokenEvents, ['abc', 'def']);
      expect(allCount, 3);

      cancelKey();
      cancelAll();

      storage.write('token', 'ghi');
      expect(tokenEvents, ['abc', 'def']); // No new events after cancel
    });

    test('App facade shorthands integrate seamlessly', () async {
      await App.initStorage(container: 'default', path: tempDir.path);

      App.storageWrite('theme', 'dark');
      expect(App.storageRead<String>('theme'), 'dark');
      expect(App.storage.has('theme'), true);

      App.storage.remove('theme');
      expect(App.storage.has('theme'), false);
    });

    testWidgets(
        'MasterApp with persistLocale & persistTheme automatically restores and saves preferences',
        (tester) async {
      await App.initStorage(container: 'default', path: tempDir.path);

      // Pre-seed storage with Arabic and Dark Mode preferences
      App.storageWrite('appforge_locale', 'ar');
      App.storageWrite('appforge_theme_mode', 'dark');

      await tester.pumpWidget(
        const MasterApp(
          persistLocale: true,
          persistTheme: true,
          home: Scaffold(body: Text('APP_CONTENT')),
        ),
      );

      // 1. Verify preferences were restored automatically before render
      expect(App.locale.languageCode, 'ar');
      expect(App.themeMode, ThemeMode.dark);
      expect(App.isRtl, true);

      // 2. Change locale in app -> Verify saved automatically to storage
      App.setLocale(const Locale('en'));
      await tester.pump();

      expect(App.storageRead<String>('appforge_locale'), 'en');

      // 3. Toggle theme mode -> Verify saved automatically to storage
      App.setThemeMode(ThemeMode.light);
      await tester.pump(const Duration(milliseconds: 100));

      expect(App.storageRead<String>('appforge_theme_mode'), 'light');
    });

    testWidgets(
        'Simulated App Restart: User changes language, app reboots, selected language is restored',
        (tester) async {
      await App.initStorage(container: 'default', path: tempDir.path);

      // 1. Initial boot with initialLocale: ar
      await tester.pumpWidget(
        const MasterApp(
          persistLocale: true,
          initialLocale: Locale('ar'),
          home: Scaffold(body: Text('APP_CONTENT')),
        ),
      );

      expect(App.locale.languageCode, 'ar');
      expect(App.isRtl, true);

      // 2. User changes language to English
      App.setLocale(const Locale('en'));
      await tester.pump();

      // Verify immediate RAM and atomic disk storage
      expect(App.locale.languageCode, 'en');
      expect(App.storageRead<String>('appforge_locale'), 'en');

      // 3. SIMULATE COMPLETE PROCESS EXIT / REBOOT
      // Clears memory cache, but disk file remains intact
      AppStorage.resetMemoryCacheOnly();

      // 4. Cold App Launch (main() execution sequence)
      await App.initStorage(container: 'default', path: tempDir.path);

      // Verify RAM cache loaded the persisted language 'en'
      expect(App.storageRead<String>('appforge_locale'), 'en');

      // 5. Mount MasterApp again (fresh root build)
      await tester.pumpWidget(
        const MasterApp(
          persistLocale: true,
          initialLocale:
              Locale('ar'), // would be 'ar' if persistence wasn't active
          home: Scaffold(body: Text('APP_CONTENT')),
        ),
      );

      // 6. VERIFY: The selected language 'en' is restored instead of the default 'ar'!
      expect(App.locale.languageCode, 'en');
      expect(App.isRtl, false);
    });

    test('Copy-on-read & copy-on-write isolation prevents aliasing bugs',
        () async {
      final storage =
          await AppStorage.init(container: 'isolation_box', path: tempDir.path);
      storage.write('items', ['apple', 'banana']);
      final readItems = storage.read<List>('items')!;
      readItems.add('cherry'); // In-place mutation of the returned reference

      // Internal storage must remain unaffected until write() is called
      expect(storage.read<List>('items'), ['apple', 'banana']);

      // Writing back the mutated list must NOT hit a no-op comparison bug
      storage.write('items', readItems);
      storage.saveSync();

      expect(storage.read<List>('items'), ['apple', 'banana', 'cherry']);
    });

    test('Throws ArgumentError on non-JSON values at write time', () async {
      final storage = await AppStorage.init(
          container: 'validation_box', path: tempDir.path);

      expect(() => storage.write('date', DateTime.now()), throwsArgumentError);
      expect(() => storage.write('nan', double.nan), throwsArgumentError);
      expect(() => storage.write('inf', double.infinity), throwsArgumentError);
      expect(() => storage.write('bad_map', {123: 'val'}), throwsArgumentError);
      expect(() => storage.writeAll({'ok': 1, 'bad': DateTime.now()}),
          throwsArgumentError);
      // Ensure nothing was partially written on writeAll failure
      expect(storage.has('ok'), false);
    });

    test('Pre-init writes merge on top of disk data without being overwritten',
        () async {
      // 1. First session writes user_id = 1, theme = dark
      final storage1 =
          await AppStorage.init(container: 'pre_init_box', path: tempDir.path);
      storage1.write('user_id', 1);
      storage1.write('theme', 'dark');
      storage1.saveSync();

      // Simulate app restart
      AppStorage.resetMemoryCacheOnly();

      // 2. Pre-init write before AppStorage.init() completes
      final storage2 = AppStorage('pre_init_box');
      storage2.write('theme', 'light'); // user/logic wrote light before init
      storage2.write('new_flag', true);

      // Now init is called
      await AppStorage.init(container: 'pre_init_box', path: tempDir.path);

      // user_id restored from disk
      expect(storage2.read<int>('user_id'), 1);
      // pre-init writes preserved on top!
      expect(storage2.read<String>('theme'), 'light');
      expect(storage2.read<bool>('new_flag'), true);
    });

    test('clear() notifies key listeners with null', () async {
      final storage =
          await AppStorage.init(container: 'clear_box', path: tempDir.path);
      storage.write('key1', 'val1');
      dynamic notifiedVal;
      storage.listenKey('key1', (val) {
        notifiedVal = val;
      });

      storage.clear();
      expect(notifiedVal, isNull);
      expect(storage.has('key1'), false);
    });

    test('Supports typed collection casts in read<T>', () async {
      final storage =
          await AppStorage.init(container: 'types_box', path: tempDir.path);
      storage.write('tags', ['a', 'b', 'c']);
      storage.write('numbers', [1, 2, 3]);
      storage.write('scores', [1.5, 2.5]);
      storage.write('flags', [true, false]);
      storage.write('map_str', {'x': 'hello'});
      storage.write('map_int', {'x': 10});

      expect(storage.read<List<String>>('tags'), ['a', 'b', 'c']);
      expect(storage.read<List<int>>('numbers'), [1, 2, 3]);
      expect(storage.read<List<double>>('scores'), [1.5, 2.5]);
      expect(storage.read<List<bool>>('flags'), [true, false]);
      expect(storage.read<Map<String, String>>('map_str'), {'x': 'hello'});
      expect(storage.read<Map<String, int>>('map_int'), {'x': 10});
    });

    test('Lifecycle state change flushes pending writes', () async {
      final storage =
          await AppStorage.init(container: 'lifecycle_box', path: tempDir.path);
      storage.write('status', 'running');
      expect(storage.hasPendingWrites, true);

      // Simulate AppLifecycleState.paused via AppLifecycleManager
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(storage.hasPendingWrites, false);

      final file = File('${tempDir.path}/.appforge_lifecycle_box.json');
      expect(file.existsSync(), true);
      expect(file.readAsStringSync().contains('running'), true);
    });
  });
}
