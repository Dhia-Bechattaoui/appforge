import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

void main() {
  group('Step 10: Zero-Dependency Network Connectivity Monitor', () {
    setUp(() {
      AppConnectivity.instance.reset();
    });

    tearDown(() {
      AppConnectivity.instance.reset();
    });

    test('Initial connectivity defaults to online (true)', () {
      expect(App.isOnline.value, true);
      expect(App.isOffline, false);
    });

    test('Custom checker updates App.isOnline and App.isOffline reactively',
        () async {
      bool mockReachability = true;
      AppConnectivity.instance.customChecker = () async => mockReachability;

      // 1. Initial check returns true
      final status1 = await App.checkConnectivity();
      expect(status1, true);
      expect(App.isOnline.value, true);
      expect(App.isOffline, false);

      // 2. Simulate offline event
      mockReachability = false;
      final status2 = await App.checkConnectivity();
      expect(status2, false);
      expect(App.isOnline.value, false);
      expect(App.isOffline, true);

      // 3. Simulate recovery
      mockReachability = true;
      final status3 = await App.checkConnectivity();
      expect(status3, true);
      expect(App.isOnline.value, true);
      expect(App.isOffline, false);
    });

    test('onConnectivityChanged stream emits status updates', () async {
      bool mockReachability = true;
      AppConnectivity.instance.customChecker = () async => mockReachability;

      final history = <bool>[];
      final subscription = App.onConnectivityChanged.listen((isOnline) {
        history.add(isOnline);
      });

      // Initially online
      mockReachability = false;
      await App.checkConnectivity();

      mockReachability = true;
      await App.checkConnectivity();

      // Yield event loop
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(history, [false, true]);
      await subscription.cancel();
    });

    testWidgets('Watch widget reactively rebuilds when App.isOnline changes',
        (tester) async {
      bool mockReachability = true;
      AppConnectivity.instance.customChecker = () async => mockReachability;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Watch(
              (context) => Text(
                App.isOnline.value ? 'ONLINE_MODE' : 'OFFLINE_BANNER',
              ),
            ),
          ),
        ),
      );

      // Initial render shows ONLINE_MODE
      expect(find.text('ONLINE_MODE'), findsOneWidget);
      expect(find.text('OFFLINE_BANNER'), findsNothing);

      // Switch to offline
      mockReachability = false;
      await App.checkConnectivity();
      await tester.pump();

      expect(find.text('OFFLINE_BANNER'), findsOneWidget);
      expect(find.text('ONLINE_MODE'), findsNothing);

      // Switch back to online
      mockReachability = true;
      await App.checkConnectivity();
      await tester.pump();

      expect(find.text('ONLINE_MODE'), findsOneWidget);
      expect(find.text('OFFLINE_BANNER'), findsNothing);
    });

    test('startConnectivityMonitor polls periodically and stops cleanly',
        () async {
      int checkCount = 0;
      AppConnectivity.instance.customChecker = () async {
        checkCount++;
        return true;
      };

      // Start monitor with high frequency for test
      App.startConnectivityMonitor(interval: const Duration(milliseconds: 50));
      expect(checkCount, 1); // Immediate initial check

      // Wait 120ms to allow ~2 ticks
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(checkCount >= 2, true);

      // Stop monitor
      App.stopConnectivityMonitor();
      final capturedCount = checkCount;

      // Wait another 100ms and verify count didn't increase
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(checkCount, capturedCount);
    });

    test('Deduplicates concurrent in-flight checkConnection requests',
        () async {
      int physicalChecks = 0;
      AppConnectivity.instance.customChecker = () async {
        physicalChecks++;
        await Future.delayed(const Duration(milliseconds: 50));
        return true;
      };

      // Launch 3 simultaneous checks
      final futures = [
        App.checkConnectivity(),
        App.checkConnectivity(),
        App.checkConnectivity(),
      ];

      final results = await Future.wait(futures);

      expect(results, [true, true, true]);
      expect(physicalChecks, 1); // Deduplicated to a single check
    });

    test('Pauses periodic polling on app background and resumes on foreground',
        () async {
      int checkCount = 0;
      AppConnectivity.instance.customChecker = () async {
        checkCount++;
        return true;
      };

      App.startConnectivityMonitor(interval: const Duration(milliseconds: 50));
      expect(checkCount, 1);

      // Simulate app backgrounding
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.paused);

      final countAtPause = checkCount;
      await Future.delayed(const Duration(milliseconds: 120));
      // Count should NOT advance while paused
      expect(checkCount, countAtPause);

      // Simulate app foregrounding
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Resumed triggers immediate check and restarts periodic timer
      await Future.delayed(const Duration(milliseconds: 60));
      expect(checkCount > countAtPause, true);

      App.stopConnectivityMonitor();
    });
  });
}
