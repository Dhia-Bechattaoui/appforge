import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appforge/appforge.dart';

class TestCounterController extends AppController {
  final count = 0.obs;
  bool readyCalled = false;
  bool closeCalled = false;

  @override
  void onReady() {
    super.onReady();
    readyCalled = true;
  }

  @override
  void onClose() {
    closeCalled = true;
    super.onClose();
  }

  void increment() {
    count.value++;
  }
}

class TestAuthService {
  final bool isLoggedIn;
  TestAuthService(this.isLoggedIn);
}

void main() {
  setUp(() {
    App.resetLocator(clearPermanent: true);
  });

  group('Service Locator (AppLocator)', () {
    test('App.put and App.find retrieves exact instance', () {
      final controller = TestCounterController();
      App.put(controller);

      expect(App.isRegistered<TestCounterController>(), isTrue);
      final found = App.find<TestCounterController>();
      expect(found, same(controller));
      expect(found.isInitialized, isTrue);
    });

    test('App.find throws StateError with clear message if not registered', () {
      expect(
        () => App.find<TestAuthService>(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('TestAuthService'),
        )),
      );
    });

    test('App.lazyPut instantiates on first access (Tier 2 JIT)', () {
      var factoryCalled = false;
      App.lazyPut<TestAuthService>(() {
        factoryCalled = true;
        return TestAuthService(true);
      });

      expect(factoryCalled, isFalse);
      expect(App.isRegistered<TestAuthService>(), isTrue);

      final service = App.find<TestAuthService>();
      expect(factoryCalled, isTrue);
      expect(service.isLoggedIn, isTrue);
    });

    test('App.putAsync supports deferred background initialization (Tier 1)',
        () async {
      final service = await App.putAsync<TestAuthService>(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return TestAuthService(true);
      });

      expect(service.isLoggedIn, isTrue);
      expect(App.find<TestAuthService>().isLoggedIn, isTrue);
    });

    test('App.delete disposes controller and runs onClose hook', () {
      final controller = TestCounterController();
      App.put(controller);

      expect(controller.closeCalled, isFalse);
      final deleted = App.delete<TestCounterController>();

      expect(deleted, isTrue);
      expect(controller.closeCalled, isTrue);
      expect(controller.isDisposed, isTrue);
      expect(App.isRegistered<TestCounterController>(), isFalse);
    });

    test('Tagged instances allow multiple registrations of same type', () {
      final primary = TestCounterController();
      final secondary = TestCounterController();

      App.put(primary, tag: 'primary');
      App.put(secondary, tag: 'secondary');

      expect(App.find<TestCounterController>(tag: 'primary'), same(primary));
      expect(
          App.find<TestCounterController>(tag: 'secondary'), same(secondary));
    });
  });

  group('UiState Machine', () {
    test('transitions cleanly between discrete states', () {
      UiState<String> state = const UiState.idle();
      expect(state.isIdle, isTrue);
      expect(state.dataOrNull, isNull);

      state = const UiState.loading();
      expect(state.isLoading, isTrue);
      expect(state.isIdle, isFalse);

      state = const UiState.success('Data Loaded');
      expect(state.isSuccess, isTrue);
      expect(state.dataOrNull, equals('Data Loaded'));

      state = const UiState.failure('Network timeout');
      expect(state.isFailure, isTrue);
      expect(state.messageOrNull, equals('Network timeout'));
    });

    test('when pattern matching executes strictly active branch', () {
      const UiState<int> state = UiState.success(42);

      final result = state.when(
        idle: () => 'idle',
        loading: () => 'loading',
        success: (data) => 'success $data',
        failure: (msg, err, st) => 'failure $msg',
      );

      expect(result, equals('success 42'));
    });
  });

  group('Rx Primitives and Reactivity', () {
    test('.obs extension creates reactive variables', () {
      final count = 0.obs;
      final text = 'hello'.obs;

      expect(count.value, equals(0));
      expect(text.value, equals('hello'));
    });

    test('notifies listeners only when value changes by equality', () {
      final count = 10.obs;
      var notifications = 0;

      count.listen(() => notifications++);

      count.value = 10; // Same value -> no notification
      expect(notifications, equals(0));

      count.value = 20; // Changed -> 1 notification
      expect(notifications, equals(1));
    });

    test('update and refresh force notification', () {
      final list = [1, 2, 3].obs;
      var notified = false;

      list.listen(() => notified = true);

      list.update((val) => val.add(4));
      expect(notified, isTrue);
      expect(list.value, equals([1, 2, 3, 4]));
    });

    test('AppController.autoCancel cancels subscription on onClose', () {
      final controller = TestCounterController();
      final rx = 0.obs;
      var notifications = 0;

      final sub = rx.listen(() => notifications++);
      controller.autoCancel(sub);

      rx.value = 1;
      expect(notifications, equals(1));

      controller.onClose();

      rx.value =
          2; // Should NOT increment notifications since subscription was auto-cancelled
      expect(notifications, equals(1));
      expect(sub.isCancelled, isTrue);
    });
  });

  group('Watch Widget Integration', () {
    testWidgets('Watch rebuilds surgically only when observed Rx changes',
        (tester) async {
      final countA = 0.obs;
      final countB = 100.obs;
      var buildCount = 0;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Watch((context) {
            buildCount++;
            return Text('CountA: ${countA.value}');
          }),
        ),
      );

      expect(find.text('CountA: 0'), findsOneWidget);
      expect(buildCount, equals(1));

      // Mutate countB: Watch does NOT observe countB, so it must NOT rebuild!
      countB.value = 200;
      await tester.pump();
      expect(buildCount, equals(1));

      // Mutate countA: Watch observes countA, so it MUST rebuild!
      countA.value = 1;
      await tester.pump();
      expect(find.text('CountA: 1'), findsOneWidget);
      expect(buildCount, equals(2));
    });

    testWidgets('Watch cleans up listeners on unmount (zero zombie listeners)',
        (tester) async {
      final count = 0.obs;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Watch((context) => Text('Value: ${count.value}')),
        ),
      );

      expect(find.text('Value: 0'), findsOneWidget);

      // Unmount the Watch widget
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox.shrink(),
        ),
      );

      // Mutate count after unmount: should not throw deactivated widget error
      count.value = 999;
      await tester.pump();
      expect(find.text('Value: 999'), findsNothing);
    });

    testWidgets(
        'Watch.state renders discrete UI states without invalid collisions',
        (tester) async {
      final state = const UiState<String>.loading().obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Watch.state<String>(
              state: state,
              onLoading: (_) => const Text('SpinnerActive'),
              onSuccess: (_, data) => Text('Payload: $data'),
              onFailure: (_, msg, __) => Text('Error: $msg'),
            ),
          ),
        ),
      );

      expect(find.text('SpinnerActive'), findsOneWidget);

      state.value = const UiState.success('Profile Loaded');
      await tester.pump();
      expect(find.text('Payload: Profile Loaded'), findsOneWidget);

      state.value = const UiState.failure('Forbidden 403');
      await tester.pump();
      expect(find.text('Error: Forbidden 403'), findsOneWidget);
    });

    testWidgets(
        'AppBind binds controller lifecycle to widget route and unmounts cleanly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppBind<TestCounterController>(
            create: () => TestCounterController(),
            builder: (context, controller) {
              return Watch(
                  (_) => Text('BoundCount: ${controller.count.value}'));
            },
          ),
        ),
      );

      // Verify controller registered and ready
      expect(App.isRegistered<TestCounterController>(), isTrue);
      expect(find.text('BoundCount: 0'), findsOneWidget);

      final controller = App.find<TestCounterController>();
      await tester.pumpAndSettle(); // Triggers postFrameCallback
      expect(controller.readyCalled, isTrue);

      // Unmount screen
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));

      // Controller should be automatically deleted and disposed
      expect(App.isRegistered<TestCounterController>(), isFalse);
      expect(controller.closeCalled, isTrue);
    });

    test(
        'Rx.listen passes new value and Rx.listenPrev passes previous and next values',
        () {
      final count = 100.obs;
      int? receivedValue;
      int? prevVal;
      int? nextVal;

      count.listen((val) => receivedValue = val);
      count.listenPrev((p, n) {
        prevVal = p;
        nextVal = n;
      });

      count.value = 250;

      expect(receivedValue, equals(250));
      expect(prevVal, equals(100));
      expect(nextVal, equals(250));
    });

    testWidgets(
        'Watch.listen executes listener callback without rebuilding child',
        (tester) async {
      final status = 'initial'.obs;
      String? sideEffect;
      var childBuilds = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Watch.listen<String>(
            target: status,
            listener: (context, value) {
              sideEffect = 'Notified: $value';
            },
            child: Builder(
              builder: (context) {
                childBuilds++;
                return const Text('StaticChild');
              },
            ),
          ),
        ),
      );

      expect(childBuilds, equals(1));
      expect(find.text('StaticChild'), findsOneWidget);

      status.value = 'updated';
      await tester.pump();

      expect(sideEffect, equals('Notified: updated'));
      expect(childBuilds, equals(1)); // Child did NOT rebuild!
    });
  });

  group('State Engine Integrity (audit regressions)', () {
    Widget host(Widget child) =>
        Directionality(textDirection: TextDirection.ltr, child: child);

    testWidgets('disposed Watch releases every listener (no leak)',
        (tester) async {
      final a = 0.obs;
      final b = 'x'.obs;

      await tester.pumpWidget(host(Watch((_) => Text('${a.value}${b.value}'))));
      expect(a.listenerCount, 1);
      expect(b.listenerCount, 1);

      await tester.pumpWidget(host(const SizedBox.shrink()));
      expect(a.listenerCount, 0);
      expect(b.listenerCount, 0);
    });

    testWidgets('Watch.listen releases its listener on dispose',
        (tester) async {
      final status = 0.obs;
      await tester.pumpWidget(host(Watch.listen<int>(
        target: status,
        listener: (_, __) {},
        child: const SizedBox.shrink(),
      )));
      expect(status.listenerCount, 1);

      await tester.pumpWidget(host(const SizedBox.shrink()));
      expect(status.listenerCount, 0);
    });

    testWidgets('rebuilding repeatedly never stacks duplicate listeners',
        (tester) async {
      final count = 0.obs;
      await tester.pumpWidget(host(Watch((_) => Text('${count.value}'))));

      for (var i = 1; i <= 20; i++) {
        count.value = i;
        await tester.pump();
      }
      expect(find.text('20'), findsOneWidget);
      expect(count.listenerCount, 1);
    });

    testWidgets('two Rx holding equal values are tracked independently',
        (tester) async {
      final a = 0.obs;
      final b = 0.obs;
      var builds = 0;

      await tester.pumpWidget(host(Watch((_) {
        builds++;
        return Text('${a.value}-${b.value}');
      })));
      expect(a.listenerCount, 1);
      expect(b.listenerCount, 1);

      b.value = 5;
      await tester.pump();
      expect(builds, 2);
      expect(find.text('0-5'), findsOneWidget);
    });

    testWidgets('conditional dependencies are unsubscribed when no longer read',
        (tester) async {
      final showDetails = true.obs;
      final details = 'd'.obs;
      var builds = 0;

      await tester.pumpWidget(host(Watch((_) {
        builds++;
        return Text(showDetails.value ? details.value : 'hidden');
      })));
      expect(details.listenerCount, 1);

      showDetails.value = false;
      await tester.pump();
      expect(details.listenerCount, 0);

      final before = builds;
      details.value = 'changed';
      await tester.pump();
      expect(builds, before); // no wasted rebuild

      showDetails.value = true;
      await tester.pump();
      expect(details.listenerCount, 1);
      expect(find.text('changed'), findsOneWidget);
    });

    testWidgets('mutating an Rx during another widget build defers safely',
        (tester) async {
      final counter = 0.obs;

      await tester.pumpWidget(host(Column(children: [
        Watch((_) => Text('value ${counter.value}')),
        Builder(builder: (_) {
          if (counter.value == 0) counter.value = 1; // mutation mid-build
          return const SizedBox.shrink();
        }),
      ])));
      expect(tester.takeException(), isNull);

      await tester.pump();
      expect(find.text('value 1'), findsOneWidget);
    });

    test('Rx equality is identity-based and hashing is stable', () {
      final a = 1.obs;
      final b = 1.obs;
      expect(a == b, isFalse);
      expect(a.value == b.value, isTrue);

      final set = <Rx<int>>{a};
      a.value = 99; // mutation must not corrupt hashing
      expect(set.contains(a), isTrue);
      expect(set.remove(a), isTrue);
    });

    test('listen rejects unsupported callback shapes at registration', () {
      final rx = 0.obs;
      expect(
        () => rx.listen((int a, int b) {}),
        throwsA(isA<ArgumentError>()),
      );
      expect(rx.listenerCount, 0);
    });

    test('listener exceptions are reported, never swallowed or re-invoked', () {
      final rx = 0.obs;
      var throwingCalls = 0;
      var healthyCalls = 0;
      final reported = <FlutterErrorDetails>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = originalOnError);

      rx.listen((int v) {
        throwingCalls++;
        throw StateError('boom');
      });
      rx.listen(() => healthyCalls++);

      rx.value = 1;
      FlutterError.onError = originalOnError;

      expect(throwingCalls, 1); // invoked exactly once
      expect(healthyCalls, 1); // siblings still notified
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
    });

    test('cancelling one subscription keeps other registrations of same fn',
        () {
      final rx = 0.obs;
      var calls = 0;
      void onChange() => calls++;

      final first = rx.listen(onChange);
      rx.listen(onChange);
      first.cancel();

      rx.value = 1;
      expect(calls, 1);
      expect(rx.listenerCount, 1);
    });

    test('listener removed mid-dispatch is not invoked afterwards', () {
      final rx = 0.obs;
      var secondCalls = 0;
      late RxSubscription second;
      rx.listen(() => second.cancel());
      second = rx.listen(() => secondCalls++);

      rx.value = 1;
      expect(secondCalls, 0);
    });

    test(
        'AppLocator stack: multiple instances of same type pushed and popped independently',
        () {
      final c1 = TestCounterController();
      final c2 = TestCounterController();

      App.put(c1, stack: true);
      expect(App.find<TestCounterController>(), same(c1));

      App.put(c2, stack: true);
      expect(App.find<TestCounterController>(), same(c2));

      // Delete top instance c2
      final deleted = App.delete<TestCounterController>(instance: c2);
      expect(deleted, isTrue);
      expect(c2.isDisposed, isTrue);
      expect(c1.isDisposed, isFalse);

      // Now top instance is c1
      expect(App.find<TestCounterController>(), same(c1));

      // Delete c1
      App.delete<TestCounterController>(instance: c1);
      expect(c1.isDisposed, isTrue);
      expect(App.isRegistered<TestCounterController>(), isFalse);
    });

    testWidgets(
        'AppBind nested/stacked routes dispose only child controller on pop',
        (tester) async {
      TestCounterController? c1;
      TestCounterController? c2;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: App.navigatorKey,
          home: AppBind<TestCounterController>(
            init: () => TestCounterController(),
            builder: (ctx, ctrl1) {
              c1 = ctrl1;
              return Scaffold(
                body: Text('Level 1: count=${ctrl1.count.value}'),
              );
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(c1, isNotNull);
      expect(App.find<TestCounterController>(), same(c1));

      // Push level 2 with identical controller type
      App.to(
        AppBind<TestCounterController>(
          create: () => TestCounterController(),
          builder: (ctx, ctrl2) {
            c2 = ctrl2;
            return Scaffold(
              body: Text('Level 2: count=${ctrl2.count.value}'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(c2, isNotNull);
      expect(c1, isNot(same(c2)));
      expect(App.find<TestCounterController>(), same(c2));
      expect(c1!.isDisposed, isFalse);
      expect(c2!.isDisposed, isFalse);

      // Pop level 2
      App.back();
      await tester.pumpAndSettle();

      // c2 disposed, c1 intact and active
      expect(c2!.isDisposed, isTrue);
      expect(c1!.isDisposed, isFalse);
      expect(App.find<TestCounterController>(), same(c1));
      expect(find.text('Level 1: count=0'), findsOneWidget);
    });
  });
}
