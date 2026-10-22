import 'dart:async';
import 'package:flutter/foundation.dart';

/// Internal interface for consumers that track reactive dependencies.
abstract class RxConsumer {
  /// Registers an [Rx] dependency that was read during evaluation.
  void addDependency(RxNotifier dependency);
}

/// Evaluation context stack for automatic reactive dependency tracking.
class EvaluationContext {
  EvaluationContext._();

  static final List<RxConsumer> _stack = [];

  /// Current active consumer in the evaluation stack, or null if none.
  static RxConsumer? get current => _stack.isEmpty ? null : _stack.last;

  /// Pushes a consumer to the evaluation stack.
  static void push(RxConsumer consumer) {
    _stack.add(consumer);
  }

  /// Pops a consumer from the evaluation stack.
  static void pop() {
    if (_stack.isNotEmpty) {
      _stack.removeLast();
    }
  }
}

/// Handle for cancelling an active [Rx] listener subscription.
class RxSubscription {
  final VoidCallback _cancelCallback;
  bool _isCancelled = false;

  RxSubscription(this._cancelCallback);

  /// Whether the subscription has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Cancels the subscription, removing the listener from the [Rx] instance.
  void cancel() {
    if (!_isCancelled) {
      _isCancelled = true;
      _cancelCallback();
    }
  }
}

/// Common interface for notifiers that report reactive changes.
abstract class RxNotifier {
  /// Registers an external listener callback.
  RxSubscription listen(Function listener);

  /// Unregisters an external listener callback.
  void removeListener(void Function() listener);
}

/// A reactive variable wrapper providing fine-grained, zero-dependency state updates.
///
/// Automatically registers itself with any active [Watch] widget reading its [value].
///
/// Equality is **identity-based**: two `Rx` instances are equal only if they are
/// the same object. Compare the wrapped values explicitly with `a.value == b.value`.
/// This keeps hashing stable while the value mutates, so an `Rx` can safely live
/// inside `Set`s and `Map`s (including the dependency registry of [Watch]).
class Rx<T> implements RxNotifier, ValueListenable<T> {
  T _value;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  Rx(this._value);

  /// Number of currently registered listeners.
  ///
  /// Exposed for leak-detection tests only.
  @visibleForTesting
  int get listenerCount => _listeners.length;

  /// Gets the current value.
  ///
  /// If accessed within a [Watch] widget's builder, registers this [Rx] as an
  /// automatic dependency.
  @override
  T get value {
    final consumer = EvaluationContext.current;
    if (consumer != null) {
      consumer.addDependency(this);
    }
    return _value;
  }

  /// Sets the value and triggers updates only if [newValue] differs from the current value.
  set value(T newValue) {
    if (_value != newValue) {
      _value = newValue;
      notifyListeners();
    }
  }

  /// Broadcast [Stream] of value updates.
  Stream<T> get stream {
    late StreamController<T> controller;
    RxSubscription? sub;
    controller = StreamController<T>.broadcast(
      onListen: () {
        sub = listen((val) {
          if (!controller.isClosed) controller.add(val as T);
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Forces an update and notifies all listeners, even if the value did not change by equality.
  void refresh() {
    notifyListeners();
  }

  /// Mutates the current value using [mutator] and immediately notifies listeners.
  void update(void Function(T val) mutator) {
    mutator(_value);
    notifyListeners();
  }

  /// Manually registers a listener for value changes.
  ///
  /// [listener] can be either:
  /// - A callback receiving the updated value: `void Function(T value)`
  /// - A parameterless callback: `void Function()`
  ///
  /// The callback shape is resolved **once** at registration, so dispatch is a
  /// direct call with no runtime type probing. Any other shape throws an
  /// [ArgumentError] immediately instead of failing silently later.
  ///
  /// Returns an [RxSubscription] handle for clean cancellation.
  @override
  RxSubscription listen(Function listener) {
    final VoidCallback callback;
    if (listener is void Function(T)) {
      callback = () => listener(_value);
    } else if (listener is void Function()) {
      // Wrapped so every registration owns a unique entry: cancelling one
      // subscription never removes another registration of the same function.
      callback = () => listener();
    } else {
      throw ArgumentError.value(
        listener,
        'listener',
        'Rx<$T>.listen expects `void Function($T)` or `void Function()`',
      );
    }
    return _register(callback);
  }

  /// Listens to value changes, delivering both the `previous` and `next` values.
  ///
  /// Example:
  /// ```dart
  /// controller.balance.listenPrev((previous, next) {
  ///   if (next < previous) App.snackbar('Payment', 'Balance decreased');
  /// });
  /// ```
  RxSubscription listenPrev(void Function(T previous, T next) listener) {
    var previous = _value;
    return _register(() {
      final current = _value;
      listener(previous, current);
      previous = current;
    });
  }

  RxSubscription _register(VoidCallback callback) {
    _listeners.add(callback);
    return RxSubscription(() => _listeners.remove(callback));
  }

  @override
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  @override
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  /// Notifies all registered listeners of a value change.
  ///
  /// - Listeners removed by an earlier listener during the same dispatch are skipped.
  /// - An exception thrown by one listener is reported through
  ///   [FlutterError.reportError] and never prevents the remaining listeners
  ///   from being notified.
  void notifyListeners() {
    if (_listeners.isEmpty) return;
    if (_listeners.length == 1) {
      _dispatch(_listeners.first);
      return;
    }
    final snapshot = _listeners.toList(growable: false);
    for (final listener in snapshot) {
      if (_listeners.contains(listener)) _dispatch(listener);
    }
  }

  void _dispatch(VoidCallback listener) {
    try {
      listener();
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'appforge',
        context: ErrorDescription('while notifying listeners of Rx<$T>'),
      ));
    }
  }

  /// Returns the current value as a [String].
  @override
  String toString() => _value.toString();
}

/// Extension enabling the `.obs` reactive syntax on any Dart object or value.
extension RxExtension<T> on T {
  /// Converts any value into an [Rx] reactive variable.
  ///
  /// Example:
  /// ```dart
  /// final count = 0.obs;
  /// final name = 'Dhia'.obs;
  /// final state = const UiState.idle().obs;
  /// ```
  Rx<T> get obs => Rx<T>(this);
}

/// Ergonomic extensions on boolean reactive variables.
extension RxBoolExtension on Rx<bool> {
  /// Toggles the boolean value and returns the new state.
  bool toggle() {
    value = !value;
    return value;
  }
}
