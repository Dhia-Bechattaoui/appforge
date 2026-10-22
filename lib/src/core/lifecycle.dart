import 'package:flutter/widgets.dart';
import '../state/locator.dart';
import '../state/rx.dart';

/// Central manager observing operating system application lifecycle transitions.
///
/// Dispatches OS lifecycle events (resumed, paused, inactive, detached, hidden)
/// directly to active [AppController]s and global listeners without boilerplate.
class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager._() {
    WidgetsBinding.instance.addObserver(this);
    // Initialize with current platform state if available
    final initial = WidgetsBinding.instance.lifecycleState;
    if (initial != null) {
      stateNotifier.value = initial;
    }
  }

  static AppLifecycleManager? _instance;
  static AppLifecycleManager get instance =>
      _instance ??= AppLifecycleManager._();

  /// Reactive notifier holding the current [AppLifecycleState].
  final ValueNotifier<AppLifecycleState> stateNotifier =
      ValueNotifier<AppLifecycleState>(AppLifecycleState.resumed);

  final List<void Function(AppLifecycleState state)> _listeners = [];

  /// Current active [AppLifecycleState].
  AppLifecycleState get currentState => stateNotifier.value;

  /// Registers a global lifecycle transition listener callback.
  RxSubscription addListener(void Function(AppLifecycleState state) callback) {
    _listeners.add(callback);
    return RxSubscription(() => _listeners.remove(callback));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    stateNotifier.value = state;

    // 1. Notify global listeners
    for (final listener
        in List<void Function(AppLifecycleState)>.from(_listeners)) {
      listener(state);
    }

    // 2. Dispatch to all active AppControllers in AppLocator
    final controllers = AppLocator.instance.activeControllers;
    for (final controller in controllers) {
      if (controller.isDisposed) continue;
      switch (state) {
        case AppLifecycleState.resumed:
          controller.onResumed();
        case AppLifecycleState.paused:
          controller.onPaused();
        case AppLifecycleState.inactive:
          controller.onInactive();
        case AppLifecycleState.detached:
          controller.onDetached();
        case AppLifecycleState.hidden:
          controller.onHidden();
      }
    }
  }

  /// Removes the observer. Used primarily during testing cleanup.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _listeners.clear();
    if (identical(_instance, this)) {
      _instance = null;
    }
  }
}
