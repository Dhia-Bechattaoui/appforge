import 'dart:async';
import 'package:flutter/widgets.dart';
import 'rx.dart';

/// Base controller class with deterministic lifecycle management.
///
/// Ensures route-bound auto-disposal to eliminate zombie listeners,
/// dangling streams, and memory leaks.
abstract class AppController {
  bool _isInitialized = false;
  bool _isReady = false;
  bool _isDisposed = false;
  final List<RxSubscription> _autoSubscriptions = [];

  /// Whether [onInit] has been executed.
  bool get isInitialized => _isInitialized;

  /// Whether [onReady] has been executed.
  bool get isReady => _isReady;

  /// Whether [onClose] has been executed.
  bool get isDisposed => _isDisposed;

  /// Called immediately when the controller is registered or instantiated.
  @mustCallSuper
  void onInit() {
    _isInitialized = true;
  }

  /// Called after the widget frame is rendered and the controller is bound to UI.
  @mustCallSuper
  void onReady() {
    _isReady = true;
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

  /// Called when the route or widget binding is removed from the navigation stack.
  ///
  /// Cleans up all auto-subscriptions and frees resources.
  @mustCallSuper
  void onClose() {
    _isDisposed = true;
    for (final sub in _autoSubscriptions) {
      sub.cancel();
    }
    _autoSubscriptions.clear();
  }
}

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
  final bool isLazy;
  final bool isAsync;
  bool isInitialized;

  _InstanceEntry({
    T? instance,
    this.builder,
    this.asyncBuilder,
    required this.permanent,
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

  /// Registers an existing dependency instance.
  ///
  /// If [dependency] is an [AppController], its [AppController.onInit] lifecycle
  /// hook is invoked immediately and [AppController.onReady] is scheduled post-frame.
  ///
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
  }) {
    final key = _InstanceKey(T, tag);

    if (_registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (stack) {
        (existing as _InstanceEntry<T>).pushInstance(dependency);
        if (dependency is AppController) {
          dependency.onInit();
          _scheduleOnReady(dependency);
        }
        return dependency;
      } else {
        if (!existing.permanent) {
          existing.dispose();
        }
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

  void _scheduleOnReady(AppController controller) {
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!controller.isDisposed && !controller.isReady) {
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
  }) {
    final key = _InstanceKey(T, tag);
    if (_registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (!existing.permanent) {
        existing.dispose();
      }
    }

    _registry[key] = _InstanceEntry<T>(
      builder: builder,
      permanent: permanent,
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
  }) async {
    final key = _InstanceKey(T, tag);
    final dependency = await builder();

    if (_registry.containsKey(key)) {
      final existing = _registry[key]!;
      if (!existing.permanent) {
        existing.dispose();
      }
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
    final key = _InstanceKey(T, tag);
    final entry = _registry[key];

    if (entry == null) {
      throw StateError(
        'AppForge: Dependency "$key" was not found in the service locator.\n'
        'Ensure you registered it first via "App.put($T())" or "App.lazyPut(() => $T())".',
      );
    }

    if (entry.isLazy && !entry.isInitialized) {
      final created = entry.builder!();
      entry.instance = created;
      entry.isInitialized = true;
      if (created is AppController) {
        created.onInit();
        _scheduleOnReady(created);
      }
    }

    return entry.instance as T;
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
        _registry.remove(key);
      }
      return removed;
    }

    entry.dispose();
    _registry.remove(key);
    return true;
  }

  /// Checks whether a dependency of type [T] is currently registered.
  bool isRegistered<T>({String? tag}) {
    final key = _InstanceKey(T, tag);
    return _registry.containsKey(key);
  }

  /// Resets the locator. Clears non-permanent dependencies unless [clearPermanent] is true.
  void reset({bool clearPermanent = false}) {
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
      if (mounted && !_controller.isDisposed && !_controller.isReady) {
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
