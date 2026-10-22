import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

class LifecycleTestController extends AppController {
  bool resumedFired = false;
  bool pausedFired = false;
  bool inactiveFired = false;
  bool detachedFired = false;
  bool hiddenFired = false;

  @override
  void onResumed() {
    resumedFired = true;
  }

  @override
  void onPaused() {
    pausedFired = true;
  }

  @override
  void onInactive() {
    inactiveFired = true;
  }

  @override
  void onDetached() {
    detachedFired = true;
  }

  @override
  void onHidden() {
    hiddenFired = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    App.resetLocator(clearPermanent: true);
  });

  group('App Lifecycle Engine', () {
    test('updates App.lifecycleState and triggers global listeners', () {
      final states = <AppLifecycleState>[];
      final sub = App.onLifecycleChange((state) => states.add(state));

      expect(App.isForeground, isTrue);

      // Simulate OS backgrounding the app
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(App.lifecycleState, equals(AppLifecycleState.paused));
      expect(App.isBackground, isTrue);
      expect(App.isForeground, isFalse);

      // Simulate OS resuming the app
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(App.lifecycleState, equals(AppLifecycleState.resumed));
      expect(App.isForeground, isTrue);

      expect(states,
          equals([AppLifecycleState.paused, AppLifecycleState.resumed]));

      // Test cancel subscription
      sub.cancel();
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(states.length,
          equals(2)); // Did not receive inactive because cancelled
    });

    test('dispatches OS lifecycle transitions to active AppControllers', () {
      final controller = LifecycleTestController();
      App.put(controller);

      expect(controller.resumedFired, isFalse);
      expect(controller.pausedFired, isFalse);

      // Simulate backgrounding (Home button, camera launch, task switch)
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(controller.pausedFired, isTrue);

      // Simulate foreground resume
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.resumedFired, isTrue);

      // Simulate incoming call / notification overlay
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.inactive);
      expect(controller.inactiveFired, isTrue);

      // Simulate hidden
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.hidden);
      expect(controller.hiddenFired, isTrue);

      // Simulate detached
      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.detached);
      expect(controller.detachedFired, isTrue);
    });

    test('disposed controllers do not receive lifecycle events', () {
      final controller = LifecycleTestController();
      App.put(controller);
      App.delete<LifecycleTestController>();

      AppLifecycleManager.instance
          .didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(controller.pausedFired, isFalse);
    });
  });
}
