import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../localization/translations.dart';
import 'rx.dart';
import 'ui_state.dart';

/// A surgical, fine-grained reactive widget.
///
/// Automatically tracks any [Rx] variables read inside [builder] during execution,
/// rebuilding exclusively itself whenever any of those variables change.
///
/// Prevents unnecessary subtree rebuilds and avoids global layout thrashing.
class Watch extends StatefulWidget {
  final Widget Function(BuildContext context) builder;

  const Watch(this.builder, {super.key});

  /// Factory constructor for rendering discrete [UiState] machines safely.
  ///
  /// Guarantees that conflicting or impossible states (e.g., loading while showing error)
  /// cannot be rendered.
  static Widget state<T>({
    Key? key,
    required Rx<UiState<T>> state,
    Widget Function(BuildContext context)? onIdle,
    Widget Function(BuildContext context)? onLoading,
    required Widget Function(BuildContext context, T data) onSuccess,
    Widget Function(BuildContext context, String message, Object? error)?
        onFailure,
    Widget Function(BuildContext context, UiState<T> state)? orElse,
  }) {
    return Watch(
      key: key,
      (context) {
        final current = state.value;
        return switch (current) {
          UiIdle<T>() => onIdle != null
              ? onIdle(context)
              : (orElse != null
                  ? orElse(context, current)
                  : const SizedBox.shrink()),
          UiLoading<T>() => onLoading != null
              ? onLoading(context)
              : (orElse != null
                  ? orElse(context, current)
                  : Center(
                      child: Text(
                        AppLocalization.instance.translate('loading'),
                      ),
                    )),
          UiSuccess<T>(data: final data) => onSuccess(context, data),
          UiFailure<T>(message: final msg, error: final err) =>
            onFailure != null
                ? onFailure(context, msg, err)
                : (orElse != null
                    ? orElse(context, current)
                    : Center(
                        child: Text(
                          '${AppLocalization.instance.translate('error')}: $msg',
                        ),
                      )),
        };
      },
    );
  }

  /// Listens to an [Rx] target and runs [listener] for side-effects (e.g., snackbars,
  /// dialogs, navigation) whenever [target] changes, without rebuilding the [child].
  ///
  /// The [child] is never rebuilt by changes to [target]; only [listener] runs.
  ///
  /// Example:
  /// ```dart
  /// Watch.listen<int>(
  ///   target: controller.count,
  ///   listener: (context, value) {
  ///     if (value == 10) App.snackbar('مبروك!', 'وصلت إلى 10 نقاط');
  ///   },
  ///   child: const CounterDisplay(),
  /// )
  /// ```
  static Widget listen<T>({
    Key? key,
    required Rx<T> target,
    required void Function(BuildContext context, T value) listener,
    required Widget child,
  }) {
    return _WatchListener<T>(
      key: key,
      target: target,
      listener: listener,
      child: child,
    );
  }

  @override
  State<Watch> createState() => _WatchState();
}

class _WatchListener<T> extends StatefulWidget {
  final Rx<T> target;
  final void Function(BuildContext context, T value) listener;
  final Widget child;

  const _WatchListener({
    super.key,
    required this.target,
    required this.listener,
    required this.child,
  });

  @override
  State<_WatchListener<T>> createState() => _WatchListenerState<T>();
}

class _WatchListenerState<T> extends State<_WatchListener<T>> {
  RxSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant _WatchListener<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.target, widget.target)) {
      _subscription?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    _subscription = widget.target.listen((val) {
      if (mounted) {
        widget.listener(context, val as T);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _WatchState extends State<Watch> implements RxConsumer {
  /// Live subscriptions keyed by dependency **identity** (never by value).
  final Map<RxNotifier, RxSubscription> _subscriptions =
      Map<RxNotifier, RxSubscription>.identity();

  /// Dependencies read during the current build pass.
  Set<RxNotifier> _tracked = Set<RxNotifier>.identity();

  bool _rebuildDeferred = false;

  @override
  void addDependency(RxNotifier dependency) {
    _tracked.add(dependency);
  }

  void _onDependencyChanged() {
    if (!mounted) return;

    // An Rx mutated while the framework is building or laying out the tree
    // (e.g. inside another widget's build or a LayoutBuilder). Marking this
    // element dirty now would throw, so the rebuild is deferred to post-frame.
    final scheduler = SchedulerBinding.instance;
    if (scheduler.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_rebuildDeferred) return;
      _rebuildDeferred = true;
      scheduler.addPostFrameCallback((_) {
        _rebuildDeferred = false;
        if (mounted) setState(() {});
      });
      return;
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    _tracked = Set<RxNotifier>.identity();
    EvaluationContext.push(this);

    final Widget result;
    try {
      result = widget.builder(context);
    } finally {
      EvaluationContext.pop();
    }

    _reconcile();
    return result;
  }

  /// Cancels subscriptions to dependencies no longer read and subscribes to new ones.
  void _reconcile() {
    _subscriptions.removeWhere((dependency, subscription) {
      if (_tracked.contains(dependency)) return false;
      subscription.cancel();
      return true;
    });
    for (final dependency in _tracked) {
      _subscriptions.putIfAbsent(
        dependency,
        () => dependency.listen(_onDependencyChanged),
      );
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _tracked = Set<RxNotifier>.identity();
    super.dispose();
  }
}
