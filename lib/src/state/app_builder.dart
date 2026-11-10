import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'locator.dart';

/// A lightweight manual-update builder bound to an [AppController].
///
/// Rebuilds whenever `controller.update()` or `controller.update([id])` is
/// invoked—providing GetBuilder-style performance and ID filtering alongside
/// AppForge's build-phase safety (deferring rebuilds if triggered mid-build).
///
/// Example:
/// ```dart
/// AppBuilder<CounterController>(
///   id: 'counter_text',
///   builder: (controller) => Text('${controller.count}'),
/// )
/// ```
class AppBuilder<T extends AppController> extends StatefulWidget {
  /// Optional controller instance to register (or use locally when [global] is false).
  final T? init;

  /// Optional factory used only when [T] needs to be instantiated.
  final T Function()? create;

  /// Optional locator tag for distinguishing multiple registrations of [T].
  final String? tag;

  /// Optional rebuild scope ID matched by `controller.update([id])`.
  final Object? id;

  /// Whether to resolve and register [T] in [AppLocator]. Defaults to `true`.
  final bool global;

  /// Whether to remove this controller when the widget unmounts (if owned by this widget).
  final bool autoRemove;

  /// Optional lifecycle hook called during `State.initState`.
  final void Function(AppBuilderState<T> state)? initState;

  /// Optional lifecycle hook called during `State.dispose`.
  final void Function(AppBuilderState<T> state)? dispose;

  /// Builder callback receiving the active controller [T].
  final Widget Function(T controller) builder;

  const AppBuilder({
    super.key,
    this.init,
    this.create,
    this.tag,
    this.id,
    this.global = true,
    this.autoRemove = false,
    this.initState,
    this.dispose,
    required this.builder,
  });

  @override
  State<AppBuilder<T>> createState() => AppBuilderState<T>();
}

/// State backing [AppBuilder].
class AppBuilderState<T extends AppController> extends State<AppBuilder<T>> {
  late final T _controller;
  bool _ownsInstance = false;
  bool _rebuildDeferred = false;
  Object? _subscribedId;

  /// The controller bound to this [AppBuilder].
  T get controller => _controller;

  @override
  void initState() {
    super.initState();
    _resolveController();
    _subscribe();
    widget.initState?.call(this);
  }

  void _resolveController() {
    if (!widget.global) {
      final created = widget.create?.call() ?? widget.init;
      if (created == null) {
        throw StateError(
          'AppBuilder<$T>(global: false) requires either "init" or "create".',
        );
      }
      _controller = created;
      _ownsInstance = true;
      if (!_controller.isInitialized) {
        _controller.onInit();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted &&
              !_controller.isDisposed &&
              !_controller.isControllerReady) {
            _controller.onReady();
          }
        });
      }
      return;
    }

    final existing = AppLocator.instance.findOrNull<T>(tag: widget.tag);
    if (existing != null) {
      _controller = existing;
      _ownsInstance = false;
      return;
    }

    final created = widget.create?.call() ?? widget.init;
    if (created != null) {
      _controller = AppLocator.instance.put<T>(created, tag: widget.tag);
      _ownsInstance = true;
      return;
    }

    // Throws informative StateError when missing.
    _controller = AppLocator.instance.find<T>(tag: widget.tag);
  }

  void _subscribe() {
    _subscribedId = widget.id;
    if (_subscribedId != null) {
      _controller.addIdListener(_subscribedId!, _onControllerUpdated);
    } else {
      _controller.addListener(_onControllerUpdated);
    }
  }

  void _unsubscribe() {
    if (_subscribedId != null) {
      _controller.removeIdListener(_subscribedId!, _onControllerUpdated);
    } else {
      _controller.removeListener(_onControllerUpdated);
    }
    _subscribedId = null;
  }

  void _onControllerUpdated() {
    if (!mounted) return;

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
  void didUpdateWidget(covariant AppBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _unsubscribe();
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    widget.dispose?.call(this);

    if (!widget.global) {
      if (!_controller.isDisposed) {
        _controller.onClose();
      }
    } else if (widget.autoRemove && _ownsInstance) {
      AppLocator.instance.delete<T>(tag: widget.tag, instance: _controller);
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(_controller);
  }
}
