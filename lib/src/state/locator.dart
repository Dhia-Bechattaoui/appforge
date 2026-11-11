import 'dart:async';
import 'package:flutter/widgets.dart';
import 'rx.dart';

/// Base controller class with deterministic lifecycle management.
///
/// Supports both fine-grained reactive [Rx] + [Watch] observables and lightweight
/// manual rebuilds via [update] + [AppBuilder], with automatic listener cleanup
/// and route-bound disposal.
abstract class AppController {
  bool _isInitialized = false;
  bool _isControllerReady = false;
  bool _isDisposed = false;
  final List<RxSubscription> _autoSubscriptions = [];
  final Set<VoidCallback> _updateListeners = <VoidCallback>{};
  final Map<Object, Set<VoidCallback>> _idUpdateListeners = {};

  /// Whether [onInit] has been executed.
  bool get isInitialized => _isInitialized;

  /// Whether [onReady] has been executed.
  bool get isControllerReady => _isControllerReady;

  /// Whether [onClose] has been executed.
  bool get isDisposed => _isDisposed;

  /// Whether this controller has been disposed/closed.
  bool get isClosed => _isDisposed;

  /// Number of currently active manual update listeners (exposed for leak testing).
  @visibleForTesting
  int get updateListenerCount {
    var total = _updateListeners.length;
    for (final set in _idUpdateListeners.values) {
      total += set.length;
    }
    return total;
  }

  /// Called immediately when the controller is registered or instantiated.
  @mustCallSuper
  void onInit() {
    _isInitialized = true;
  }

  /// Called after the widget frame is rendered and the controller is bound to UI.
  @mustCallSuper
  void onReady() {
    _isControllerReady = true;
  }

  /// Registers an [RxSubscription] to be automatically cancelled when this
  /// controller is disposed.
  void autoCancel(RxSubscription subscription) {
    if (_isDisposed) {
      subscription.cancel();
    } else {
      _autoSubscriptions.add(subscription);
    }
  }

  /// Called when the mobile operating system brings the app to the foreground.
  ///
  /// Override to refresh stale data, check session tokens, or resume animations.
  void onResumed() {}

  /// Called when the mobile operating system backgrounds the app (e.g. Home button pressed,
  /// task switcher opened, camera launched).
  ///
  /// Override to persist unsaved draft state to disk before Android LMK or iOS Jetsam
  /// terminates the process.
  void onPaused() {}

  /// Called when an incoming phone call, Control Center, or system dialog overlays the app.
  void onInactive() {}

  /// Called when the app process is being terminated or detached.
  void onDetached() {}

  /// Called when the app becomes hidden (Flutter 3.13+).
  void onHidden() {}

  /// Registers an unscoped [listener] notified when [update] is called.
  void addListener(VoidCallback listener) {
    if (_isDisposed) return;
    _updateListeners.add(listener);
  }

  /// Unregisters a previously registered unscoped [listener].
  void removeListener(VoidCallback listener) {
    _updateListeners.remove(listener);
  }

  /// Registers an [id]-scoped [listener] notified when [update] targets [id]
  /// or performs an unscoped refresh.
  void addIdListener(Object id, VoidCallback listener) {
    if (_isDisposed) return;
    _idUpdateListeners.putIfAbsent(id, () => <VoidCallback>{}).add(listener);
  }

  /// Unregisters a previously registered [id]-scoped [listener].
  void removeIdListener(Object id, VoidCallback listener) {
    final listeners = _idUpdateListeners[id];
    if (listeners == null) return;
    listeners.remove(listener);
    if (listeners.isEmpty) {
      _idUpdateListeners.remove(id);
    }
  }

  /// Notifies [AppBuilder] listeners to rebuild UI cleanly.
  ///
  /// - When [ids] is `null` or empty, all listeners (unscoped and ID-scoped) rebuild.
  /// - When [ids] is provided, only listeners registered for those matching IDs rebuild.
  /// - When [condition] is `false`, nothing is notified.
  void update([List<Object>? ids, bool condition = true]) {
    if (!condition || _isDisposed) return;

    final targets = <VoidCallback>{};
    if (ids == null || ids.isEmpty) {
      targets.addAll(_updateListeners);
      for (final group in _idUpdateListeners.values) {
        targets.addAll(group);
      }
    } else {
      for (final id in ids) {
        final group = _idUpdateListeners[id];
        if (group != null) {
          targets.addAll(group);
        }
      }
    }

    for (final listener in List<VoidCallback>.of(targets)) {
      try {
        listener();
      } catch (error, stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'appforge',
            context: ErrorDescription(
              'while notifying AppController.update listener on $runtimeType',
            ),
          ),
        );
      }
    }
  }

  /// Called when the route or widget binding is removed from the navigation stack.
  ///
  /// Cleans up all auto-subscriptions, manual update listeners, and frees resources.
  @mustCallSuper
  void onClose() {
    _isDisposed = true;
    for (final sub in _autoSubscriptions) {
      sub.cancel();
    }
    _autoSubscriptions.clear();
    _updateListeners.clear();
    _idUpdateListeners.clear();
  }
}

/// Base service class for long-lived, singleton background and core services.
abstract class AppService extends AppController {}

/// Internal identifier key for registered instances.
class _InstanceKey {
  final Type type;
  final String? tag;

  const _InstanceKey(this.type, this.tag);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _InstanceKey && other.type == type && other.tag == tag;

  @override
  int get hashCode => Object.hash(type, tag);

  @override
  String toString() => tag != null ? '$type (tag: "$tag")' : '$type';
}

/// Metadata container for a registered dependency.
/// Metadata container for a registered dependency.
class _InstanceEntry<T> {
  final List<T> _instances = [];
  final T Function()? builder;
  final Future<T> Function()? asyncBuilder;
  final bool permanent;
  final bool fenix;
  final bool isLazy;
  final bool isAsync;
  bool isInitialized;

  _InstanceEntry({
    T? instance,
    this.builder,
    this.asyncBuilder,
    required this.permanent,
    this.fenix = false,
    required this.isLazy,
    required this.isAsync,
    required this.isInitialized,
  }) {
    if (instance != null) {
      _instances.add(instance);
    }
  }

  T? get instance => _instances.isEmpty ? null : _instances.last;
  set instance(T? val) {
    _instances.clear();
    if (val != null) _instances.add(val);
  }

  List<T> get allInstances => List.unmodifiable(_instances);

  void pushInstance(T val) {
    _instances.add(val);
    isInitialized = true;
  }

  bool removeInstance(T val) {
    final removed = _instances.remove(val);
    if (val is AppController && !val.isDisposed) {
      val.onClose();
    }
    return removed;
  }

  void dispose() {
    for (final inst in List<T>.from(_instances)) {
      if (inst is AppController && !inst.isDisposed) {
        inst.onClose();
      }
    }
    _instances.clear();
    isInitialized = false;
  }
}

/// Lightweight, memory-safe dependency injection container.
class AppLocator {
  AppLocator._();

  static final AppLocator instance = AppLocator._();

  final Map<_InstanceKey, _InstanceEntry<dynamic>> _registry = {};
  final Map<_InstanceKey, dynamic> _overrides = {};

  /// Registers a test or scoped override for [T] (with optional [tag]).
  ///
  /// While active, [find], [findOrNull], and [isRegistered] resolve to
  /// [dependency] regardless of prior or subsequent [put]/[lazyPut] calls.
  /// Returns a restorer callback that reverts this override when invoked.
  VoidCallback override<T>(T dependency, {String? tag}) {
    final key = _InstanceKey(T, tag);
    final hadPrevious = _overrides.containsKey(key);
    final previous = _overrides[key];

    _overrides[key] = dependency;
    if (dependency is AppController && !dependency.isInitialized) {
      dependency.onInit();
      _scheduleOnReady(dependency);
    }

    return () {
      if (!identical(_overrides[key], dependency)) return;
      if (hadPrevious) {
        _overrides[key] = previous;
      } else {
        _overrides.remove(key);
      }
      if (dependency is AppController && !dependency.isDisposed) {
        dependency.onClose();
      }
    };
  }

  /// Clears an active override for [T] (with optional [tag]).
  void clearOverride<T>({String? tag}) {
    final key = _InstanceKey(T, tag);
    if (!_overrides.containsKey(key)) return;
    final removed = _overrides.remove(key);
    if (removed is AppController && !removed.isDisposed) {
      removed.onClose();
    }
  }

  /// Clears and disposes all active dependency overrides.
  void clearOverrides() {
    for (final value in List<dynamic>.of(_overrides.values)) {
      if (value is AppController && !value.isDisposed) {
        value.onClose();
      }
    }
    _overrides.clear();
  }

  /// Registers an existing dependency instance.
  ///
  /// By default (`replace: false`), `put` is idempotent: if [T] (with matching
  /// [tag]) is already registered, the existing instance is returned intact
  /// (materializing a pending `lazyPut` factory if needed) without wiping state
  /// or invoking `onInit` on the redundant [dependency].
  ///
  /// Set [replace] to `true` to dispose any non-permanent registration (or replace
  /// explicitly) with [dependency].
  /// Set [stack] to `true` to push multiple instances of the same type without
  /// disposing earlier instances (used by [AppBind] for route-scoped stacking).
  ///
  /// Example:
  /// ```dart
  /// final auth = App.put(AuthController());
  /// ```
  T put<T>(
    T dependency, {
    String? tag,
    bool permanent = false,
    bool stack = false,
    bool replace = false,
  }) {
    final key = _InstanceKey(T, tag);
    if (_overrides.containsKey(key)) {
      return _overrides[key] as T;
    }

    if (_registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (stack) {
        (existing as _InstanceEntry<T>).pushInstance(dependency);
        if (dependency is AppController) {
          dependency.onInit();
          _scheduleOnReady(dependency);
        }
        return dependency;
      } else if (!replace) {
        if (existing.isLazy && !existing.isInitialized) {
          return find<T>(tag: tag);
        }
        if (existing.instance != null) {
          return existing.instance as T;
        }
      } else {
        existing.dispose();
      }
    }

    final entry = _InstanceEntry<T>(
      instance: dependency,
      permanent: permanent,
      isLazy: false,
      isAsync: false,
      isInitialized: true,
    );

    _registry[key] = entry;

    if (dependency is AppController) {
      dependency.onInit();
      _scheduleOnReady(dependency);
    }

    return dependency;
  }

  /// Registers [builder] only if [T] (with optional [tag]) is not already
  /// registered, avoiding unnecessary object construction when already present.
  T putIfAbsent<T>(
    T Function() builder, {
    String? tag,
    bool permanent = false,
  }) {
    final key = _InstanceKey(T, tag);
    if (_overrides.containsKey(key)) {
      return _overrides[key] as T;
    }
    final existing = _registry[key];
    if (existing != null) {
      if (existing.isLazy && !existing.isInitialized) {
        return find<T>(tag: tag);
      }
      if (existing.instance != null) {
        return existing.instance as T;
      }
    }
    return put<T>(builder(), tag: tag, permanent: permanent);
  }

  void _scheduleOnReady(AppController controller) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.isDisposed && !controller.isControllerReady) {
          controller.onReady();
        }
      });
    } catch (_) {
      // Binding not yet initialized in pure Dart CLI/unit tests.
    }
  }

  /// Registers a factory [builder] that instantiates [T] only upon first access via [find].
  ///
  /// Used for Just-in-Time (JIT) initialization to preserve cold-start performance.
  ///
  /// Example:
  /// ```dart
  /// App.lazyPut<HeavyService>(() => HeavyService());
  /// ```
  void lazyPut<T>(
    T Function() builder, {
    String? tag,
    bool permanent = false,
    bool fenix = false,
    bool replace = false,
  }) {
    final key = _InstanceKey(T, tag);
    if (_overrides.containsKey(key)) return;
    if (_registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (!replace && existing.permanent) {
        return;
      }
      if (replace || !existing.permanent) {
        existing.dispose();
      }
    }

    _registry[key] = _InstanceEntry<T>(
      builder: builder,
      permanent: permanent,
      fenix: fenix,
      isLazy: true,
      isAsync: false,
      isInitialized: false,
    );
  }

  /// Registers an asynchronous factory [builder] for non-blocking background hydration.
  ///
  /// Example:
  /// ```dart
  /// await App.putAsync<DatabaseService>(() async => DatabaseService.open());
  /// ```
  Future<T> putAsync<T>(
    Future<T> Function() builder, {
    String? tag,
    bool permanent = false,
    bool replace = false,
  }) async {
    final key = _InstanceKey(T, tag);
    if (_overrides.containsKey(key)) {
      return _overrides[key] as T;
    }
    if (!replace && _registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (existing.isLazy && !existing.isInitialized) {
        return find<T>(tag: tag);
      }
      if (existing.instance != null) {
        return existing.instance as T;
      }
    }

    final dependency = await builder();

    if (_registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (!replace && existing.permanent) {
        return existing.instance as T;
      }
      existing.dispose();
    }

    final entry = _InstanceEntry<T>(
      instance: dependency,
      permanent: permanent,
      isLazy: false,
      isAsync: true,
      isInitialized: true,
    );

    _registry[key] = entry;

    if (dependency is AppController) {
      dependency.onInit();
      _scheduleOnReady(dependency);
    }

    return dependency;
  }

  /// Finds and retrieves a registered dependency of type [T].
  ///
  /// Throws a clear [StateError] if the dependency is not registered.
  ///
  /// Example:
  /// ```dart
  /// final auth = App.find<AuthController>();
  /// ```
  T find<T>({String? tag}) {
    final found = findOrNull<T>(tag: tag);
    if (found == null) {
      final key = _InstanceKey(T, tag);
      throw StateError(
        'AppForge: Dependency "$key" was not found in the service locator.\n'
        'Ensure you registered it first via "App.put($T())" or "App.lazyPut(() => $T())".',
      );
    }
    return found;
  }

  /// Finds and retrieves a registered dependency of type [T], or `null` if not registered.
  T? findOrNull<T>({String? tag}) {
    final key = _InstanceKey(T, tag);
    if (_overrides.containsKey(key)) {
      return _overrides[key] as T?;
    }
    final entry = _registry[key];

    if (entry == null) return null;

    if (entry.isLazy && !entry.isInitialized) {
      final created = entry.builder!();
      entry.instance = created;
      entry.isInitialized = true;
      if (created is AppController) {
        created.onInit();
        _scheduleOnReady(created);
      }
    }

    return entry.instance as T?;
  }

  /// Removes and disposes a registered dependency of type [T].
  ///
  /// Invokes [AppController.onClose] if the instance is an [AppController].
  /// Permanent instances are not deleted unless [force] is true.
  ///
  /// If [instance] is specified, only that specific instance is removed from the
  /// instance stack, leaving any earlier registered instances intact.
  bool delete<T>({String? tag, bool force = false, T? instance}) {
    final key = _InstanceKey(T, tag);
    final entry = _registry[key];

    if (entry == null) return false;
    if (entry.permanent && !force) return false;

    if (instance != null) {
      final removed = (entry as _InstanceEntry<T>).removeInstance(instance);
      if (entry.allInstances.isEmpty) {
        if (!entry.fenix) {
          _registry.remove(key);
        }
      }
      return removed;
    }

    entry.dispose();
    if (!entry.fenix || force) {
      _registry.remove(key);
    }
    return true;
  }

  /// Checks whether a dependency of type [T] is currently registered or overridden.
  bool isRegistered<T>({String? tag}) {
    final key = _InstanceKey(T, tag);
    return _overrides.containsKey(key) || _registry.containsKey(key);
  }

  /// Resets the locator. Clears non-permanent dependencies unless [clearPermanent] is true.
  void reset({bool clearPermanent = false}) {
    if (clearPermanent) {
      clearOverrides();
    }
    final keysToRemove = <_InstanceKey>[];

    for (final entry in _registry.entries) {
      if (clearPermanent || !entry.value.permanent) {
        entry.value.dispose();
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _registry.remove(key);
    }
  }

  /// Returns all currently registered and initialized [AppController] instances.
  List<AppController> get activeControllers {
    final controllers = <AppController>[];
    for (final entry in _registry.values) {
      if (entry.isInitialized) {
        for (final inst in entry.allInstances) {
          if (inst is AppController && !inst.isDisposed) {
            controllers.add(inst);
          }
        }
      }
    }
    return controllers;
  }
}

/// Lifecycle-bound widget that automatically registers an [AppController] on mount,
/// triggers [AppController.onReady] post-frame, and auto-disposes it when unmounted.
///
/// Supports nested stacking of identical route controller types without collisions.
///
/// Prevents memory leaks and zombie listeners when navigating between routes.
class AppBind<T extends AppController> extends StatefulWidget {
  final T Function()? create;
  final T Function()? init;
  final String? tag;
  final bool autoDispose;
  final Widget Function(BuildContext context, T controller) builder;

  const AppBind({
    T Function()? create,
    T Function()? init,
    required this.builder,
    this.tag,
    this.autoDispose = true,
    super.key,
  })  : assert(create != null || init != null,
            'AppBind requires either "create" or "init" builder parameter.'),
        create = create ?? init,
        init = init ?? create;

  @override
  State<AppBind<T>> createState() => _AppBindState<T>();
}

class _AppBindState<T extends AppController> extends State<AppBind<T>> {
  late final T _controller;

  @override
  void initState() {
    super.initState();
    _controller = (widget.create ?? widget.init)!();
    AppLocator.instance.put<T>(_controller, tag: widget.tag, stack: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !_controller.isDisposed &&
          !_controller.isControllerReady) {
        _controller.onReady();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _controller);
  }

  @override
  void dispose() {
    if (widget.autoDispose) {
      AppLocator.instance
          .delete<T>(tag: widget.tag, force: true, instance: _controller);
    }
    super.dispose();
  }
}

/// Interface for declaring modular dependencies.
abstract class AppBindings {
  /// Registers dependencies into the service locator.
  void dependencies();
}

/// Convenience builder for functional dependency registration.
class BindingsBuilder implements AppBindings {
  final void Function() _builder;
  const BindingsBuilder(this._builder);

  @override
  void dependencies() => _builder();

  void call() => _builder();
}

/// Base [StatelessWidget] with convenient access to a controller registered in [AppLocator].
abstract class AppView<T> extends StatelessWidget {
  const AppView({super.key});

  /// The registered [T] controller instance.
  T get controller => AppLocator.instance.find<T>();
}

/// Typed dependency override entry for [AppTestScope].
class AppOverride<T> {
  /// The replacement dependency instance active inside the test scope.
  final T value;

  /// Optional locator tag matching `App.find<T>(tag: tag)`.
  final String? tag;

  const AppOverride(this.value, {this.tag});

  /// Applies this override to [AppLocator.instance] and returns a restorer callback.
  VoidCallback apply() => AppLocator.instance.override<T>(value, tag: tag);
}

/// Scoped widget container that applies [overrides] on mount and automatically
/// restores prior [AppLocator] state when disposed.
///
/// Example:
/// ```dart
/// await tester.pumpWidget(
///   AppTestScope(
///     overrides: [AppOverride<AuthService>(FakeAuthService())],
///     child: const MasterApp(home: LoginScreen()),
///   ),
/// );
/// ```
class AppTestScope extends StatefulWidget {
  /// Typed dependency overrides applied while this widget is mounted.
  final List<AppOverride<dynamic>> overrides;

  /// The subtree under test.
  final Widget child;

  const AppTestScope({
    required this.overrides,
    required this.child,
    super.key,
  });

  @override
  State<AppTestScope> createState() => _AppTestScopeState();
}

class _AppTestScopeState extends State<AppTestScope> {
  final List<VoidCallback> _restorers = [];

  @override
  void initState() {
    super.initState();
    for (final entry in widget.overrides) {
      _restorers.add(entry.apply());
    }
  }

  @override
  void dispose() {
    for (final restore in _restorers.reversed) {
      restore();
    }
    _restorers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
