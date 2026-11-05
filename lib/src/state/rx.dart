import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
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

  /// Cancels and disposes this subscription.
  void dispose() => cancel();
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

  /// Binds an external [Stream] to this reactive variable, updating [value] on each event.
  void bindStream(Stream<T> stream) {
    stream.listen((data) => value = data);
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

/// Ergonomic string forwarding extensions on reactive strings.
extension RxStringExtension on Rx<String> {
  /// Whether the wrapped string is empty.
  bool get isEmpty => value.isEmpty;

  /// Whether the wrapped string is not empty.
  bool get isNotEmpty => value.isNotEmpty;

  /// Number of characters in the wrapped string.
  int get length => value.length;
}

/// Common functional list extensions.
extension AppListExtension<E> on List<E> {
  /// Clears this list and populates it with all elements from [val].
  void assignAll(Iterable<E> val) {
    clear();
    addAll(val);
  }

  /// Clears this list and adds [val] as the single element.
  void assign(E val) {
    clear();
    add(val);
  }

  /// Returns the first element satisfying [test], or `null` if none match.
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// Common functional iterable extensions.
extension AppIterableExtension<E> on Iterable<E> {
  /// Returns the first element satisfying [test], or `null` if none match.
  E? firstWhereOrNull(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}

/// A nullable reactive variable wrapper.
class Rxn<T> extends Rx<T?> {
  Rxn([super.initial]);
}

// ---------------------------------------------------------------------------
// Typed Reactive Shorthands
// ---------------------------------------------------------------------------

typedef RxBool = Rx<bool>;
typedef RxInt = Rx<int>;
typedef RxDouble = Rx<double>;
typedef RxString = Rx<String>;
typedef RxnString = Rxn<String>;
typedef RxnBool = Rxn<bool>;
typedef RxnInt = Rxn<int>;
typedef RxnDouble = Rxn<double>;

/// Alias for an active reactive worker subscription.
typedef Worker = RxSubscription;

/// Calls [callback] every time [listener] changes.
Worker ever<T>(ValueListenable<T> listener, void Function(T val) callback) {
  void handler() => callback(listener.value);
  listener.addListener(handler);
  return RxSubscription(() => listener.removeListener(handler));
}

/// Calls [callback] every time any of the [listeners] change.
Worker everAll(
    List<Listenable> listeners, void Function(dynamic val) callback) {
  final subs = <void Function()>[];
  for (final l in listeners) {
    void handler() => callback(l is ValueListenable ? l.value : null);
    l.addListener(handler);
    subs.add(() => l.removeListener(handler));
  }
  return RxSubscription(() {
    for (final s in subs) {
      s();
    }
  });
}

/// Calls [callback] when [listener] changes, debounced by [time].
Worker debounce<T>(
  ValueListenable<T> listener,
  void Function(T val) callback, {
  Duration time = const Duration(milliseconds: 800),
}) {
  Timer? timer;
  void handler() {
    timer?.cancel();
    timer = Timer(time, () => callback(listener.value));
  }

  listener.addListener(handler);
  return RxSubscription(() {
    timer?.cancel();
    listener.removeListener(handler);
  });
}

/// Calls [callback] at most once per [time] duration when [listener] changes.
Worker interval<T>(
  ValueListenable<T> listener,
  void Function(T val) callback, {
  Duration time = const Duration(milliseconds: 800),
}) {
  bool inInterval = false;
  Timer? timer;
  void handler() {
    if (!inInterval) {
      inInterval = true;
      callback(listener.value);
      timer = Timer(time, () => inInterval = false);
    }
  }

  listener.addListener(handler);
  return RxSubscription(() {
    timer?.cancel();
    listener.removeListener(handler);
  });
}

// ---------------------------------------------------------------------------
// Reactive Collections
// ---------------------------------------------------------------------------

/// A reactive [List] that automatically notifies [Watch] and listeners when mutated.
class RxList<E> extends Rx<List<E>> with ListMixin<E> {
  RxList([List<E>? initial]) : super(initial ?? <E>[]);

  @override
  E operator [](int index) {
    _registerDependency();
    return value[index];
  }

  @override
  void operator []=(int index, E val) {
    value[index] = val;
    notifyListeners();
  }

  @override
  int get length {
    _registerDependency();
    return value.length;
  }

  @override
  set length(int newLength) {
    value.length = newLength;
    notifyListeners();
  }

  @override
  void add(E element) {
    value.add(element);
    notifyListeners();
  }

  @override
  void addAll(Iterable<E> iterable) {
    value.addAll(iterable);
    notifyListeners();
  }

  /// Replaces all elements with [iterable] and notifies listeners.
  void assignAll(Iterable<E> iterable) {
    value.clear();
    value.addAll(iterable);
    notifyListeners();
  }

  /// Replaces all elements with a single [element] and notifies listeners.
  void assign(E element) {
    value.clear();
    value.add(element);
    notifyListeners();
  }

  @override
  void clear() {
    if (value.isNotEmpty) {
      value.clear();
      notifyListeners();
    }
  }

  @override
  bool remove(Object? element) {
    final removed = value.remove(element);
    if (removed) notifyListeners();
    return removed;
  }

  @override
  E removeAt(int index) {
    final removed = value.removeAt(index);
    notifyListeners();
    return removed;
  }

  @override
  E removeLast() {
    final removed = value.removeLast();
    notifyListeners();
    return removed;
  }

  @override
  void removeWhere(bool Function(E element) test) {
    final lengthBefore = value.length;
    value.removeWhere(test);
    if (value.length != lengthBefore) notifyListeners();
  }

  @override
  void retainWhere(bool Function(E element) test) {
    final lengthBefore = value.length;
    value.retainWhere(test);
    if (value.length != lengthBefore) notifyListeners();
  }

  @override
  void insert(int index, E element) {
    value.insert(index, element);
    notifyListeners();
  }

  @override
  void insertAll(int index, Iterable<E> iterable) {
    value.insertAll(index, iterable);
    notifyListeners();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    value.sort(compare);
    notifyListeners();
  }

  @override
  void shuffle([math.Random? random]) {
    value.shuffle(random);
    notifyListeners();
  }

  void _registerDependency() {
    final consumer = EvaluationContext.current;
    if (consumer != null) {
      consumer.addDependency(this);
    }
  }

  @override
  Iterator<E> get iterator {
    _registerDependency();
    return value.iterator;
  }

  @override
  bool get isEmpty {
    _registerDependency();
    return value.isEmpty;
  }

  @override
  bool get isNotEmpty {
    _registerDependency();
    return value.isNotEmpty;
  }

  @override
  bool contains(Object? element) {
    _registerDependency();
    return value.contains(element);
  }
}

/// A reactive [Map] that automatically notifies [Watch] and listeners when mutated.
class RxMap<K, V>
    with MapMixin<K, V>
    implements RxNotifier, ValueListenable<Map<K, V>> {
  final Map<K, V> _data;
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  RxMap([Map<K, V>? initial]) : _data = initial ?? <K, V>{};

  @override
  Map<K, V> get value {
    _registerDependency();
    return this;
  }

  set value(Map<K, V> newValue) {
    if (!identical(_data, newValue)) {
      _data.clear();
      _data.addAll(newValue);
      notifyListeners();
    }
  }

  /// Forces an update and notifies all listeners.
  void refresh() {
    notifyListeners();
  }

  /// Broadcast stream of value changes.
  Stream<Map<K, V>> get stream {
    late StreamController<Map<K, V>> controller;
    RxSubscription? sub;
    controller = StreamController<Map<K, V>>.broadcast(
      onListen: () {
        sub = listen((val) {
          if (!controller.isClosed) controller.add(val as Map<K, V>);
        });
      },
      onCancel: () {
        sub?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  RxSubscription listen(Function listener) {
    final VoidCallback callback;
    if (listener is void Function(Map<K, V>)) {
      callback = () => listener(this);
    } else if (listener is void Function()) {
      callback = () => listener();
    } else {
      throw ArgumentError.value(
        listener,
        'listener',
        'RxMap expects void Function(Map<K, V>) or void Function()',
      );
    }
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

  /// Notifies all registered listeners of a change.
  void notifyListeners() {
    if (_listeners.isEmpty) return;
    final snapshot = _listeners.toList(growable: false);
    for (final listener in snapshot) {
      if (_listeners.contains(listener)) {
        try {
          listener();
        } catch (e, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: e,
            stack: stack,
            library: 'appforge',
          ));
        }
      }
    }
  }

  void _registerDependency() {
    final consumer = EvaluationContext.current;
    if (consumer != null) {
      consumer.addDependency(this);
    }
  }

  @override
  V? operator [](Object? key) {
    _registerDependency();
    return _data[key];
  }

  @override
  void operator []=(K key, V val) {
    _data[key] = val;
    notifyListeners();
  }

  @override
  void clear() {
    if (_data.isNotEmpty) {
      _data.clear();
      notifyListeners();
    }
  }

  @override
  Iterable<K> get keys {
    _registerDependency();
    return _data.keys;
  }

  @override
  V? remove(Object? key) {
    final removed = _data.remove(key);
    if (removed != null) notifyListeners();
    return removed;
  }

  @override
  V update(K key, V Function(V value) update, {V Function()? ifAbsent}) {
    final result = _data.update(key, update, ifAbsent: ifAbsent);
    notifyListeners();
    return result;
  }

  /// Replaces all entries with [other] and notifies listeners.
  void assignAll(Map<K, V> other) {
    _data.clear();
    _data.addAll(other);
    notifyListeners();
  }
}

/// A reactive [Set] that automatically notifies [Watch] and listeners when mutated.
class RxSet<E> extends Rx<Set<E>> with SetMixin<E> {
  RxSet([Set<E>? initial]) : super(initial ?? <E>{});

  void _registerDependency() {
    final consumer = EvaluationContext.current;
    if (consumer != null) {
      consumer.addDependency(this);
    }
  }

  @override
  bool add(E val) {
    final added = value.add(val);
    if (added) notifyListeners();
    return added;
  }

  @override
  bool contains(Object? element) {
    _registerDependency();
    return value.contains(element);
  }

  @override
  Iterator<E> get iterator {
    _registerDependency();
    return value.iterator;
  }

  @override
  int get length {
    _registerDependency();
    return value.length;
  }

  @override
  E? lookup(Object? element) {
    _registerDependency();
    return value.lookup(element);
  }

  @override
  bool remove(Object? val) {
    final removed = value.remove(val);
    if (removed) notifyListeners();
    return removed;
  }

  @override
  Set<E> toSet() {
    _registerDependency();
    return value.toSet();
  }

  @override
  void clear() {
    if (value.isNotEmpty) {
      value.clear();
      notifyListeners();
    }
  }

  /// Replaces all elements with [other] and notifies listeners.
  void assignAll(Iterable<E> other) {
    value.clear();
    value.addAll(other);
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// Collection Extensions
// ---------------------------------------------------------------------------

/// Extension enabling `.obs` on [List].
extension RxListExtension<E> on List<E> {
  /// Converts a [List] into an [RxList] reactive collection.
  RxList<E> get obs => RxList<E>(this);
}

/// Extension enabling `.obs` on [Map].
extension RxMapExtension<K, V> on Map<K, V> {
  /// Converts a [Map] into an [RxMap] reactive collection.
  RxMap<K, V> get obs => RxMap<K, V>(this);
}

/// Extension enabling `.obs` on [Set].
extension RxSetExtension<E> on Set<E> {
  /// Converts a [Set] into an [RxSet] reactive collection.
  RxSet<E> get obs => RxSet<E>(this);
}
