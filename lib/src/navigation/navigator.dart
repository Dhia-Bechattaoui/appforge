import 'package:flutter/material.dart';
import 'transitions.dart';

/// Internal observer that tracks real route transitions across all navigation mechanisms
/// (context-free App.to, system back gestures, modal sheets, and Navigator.push).
class _AppNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> _routeStack = [];

  Route<dynamic>? get currentRoute =>
      _routeStack.isEmpty ? null : _routeStack.last;

  /// Returns arguments from the current top route, or walks down the stack to
  /// find the active page arguments.
  Object? get currentArguments {
    if (_routeStack.isEmpty) return null;
    final top = _routeStack.last;
    if (top.settings.arguments != null) {
      return top.settings.arguments;
    }
    // If the top route is a modal popup/dialog without arguments,
    // look at the topmost PageRoute in the stack.
    if (top is! PageRoute) {
      for (int i = _routeStack.length - 1; i >= 0; i--) {
        final r = _routeStack[i];
        if (r is PageRoute) {
          return r.settings.arguments;
        }
      }
    }
    return top.settings.arguments;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeStack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeStack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routeStack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) {
      final index = _routeStack.indexOf(oldRoute);
      if (index != -1 && newRoute != null) {
        _routeStack[index] = newRoute;
        return;
      }
      _routeStack.remove(oldRoute);
    }
    if (newRoute != null && !_routeStack.contains(newRoute)) {
      _routeStack.add(newRoute);
    }
  }
}

/// Lightweight record of a navigation call captured while [AppNavigator] test
/// recording is enabled.
///
/// Allows pure Dart unit tests to verify controller navigation calls (`App.to`,
/// `App.off`, `App.offAll`, `App.toNamed`, `App.back`) without pumping a full
/// widget tree.
class AppNavigationRecord {
  /// The navigation action invoked (`'to'`, `'off'`, `'offAll'`, `'toNamed'`,
  /// `'offNamed'`, `'offAllNamed'`, `'back'`).
  final String action;

  /// Runtime [Type] of the target widget for widget-based navigation, if any.
  final Type? pageType;

  /// Route name passed to named or widget navigation, if any.
  final String? routeName;

  /// Arguments passed with the navigation call.
  final Object? arguments;

  /// Route parameters passed with the navigation call, if any.
  final Map<String, String>? parameters;

  /// Result value passed to `back`, `off`, or `offNamed`, if any.
  final Object? result;

  const AppNavigationRecord({
    required this.action,
    this.pageType,
    this.routeName,
    this.arguments,
    this.parameters,
    this.result,
  });
}

/// Context-free navigation controller for AppForge.
///
/// Enables routing, page pushing, popping, and argument passing from anywhere
/// in the application without requiring a [BuildContext].
class AppNavigator {
  AppNavigator._();

  static final AppNavigator instance = AppNavigator._();

  /// Global key bound to the root [NavigatorState].
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final _AppNavigatorObserver _observer = _AppNavigatorObserver();

  /// The navigator observer that tracks real route stack changes and synchronizes arguments.
  /// Automatically included in [MasterApp.navigatorObservers].
  NavigatorObserver get observer => _observer;

  /// Gets the currently active [Route], if tracked.
  Route<dynamic>? get currentRoute => _observer.currentRoute;

  /// Name of the currently active route, if available.
  String get currentRouteName => currentRoute?.settings.name ?? '';

  final List<Object?> _fallbackArgumentsStack = [];
  Map<String, String> _parameters = {};

  bool _recordForTesting = false;
  final List<AppNavigationRecord> _recordedNavigations = [];

  /// Whether navigation calls are currently captured in [recordedNavigations].
  bool get isRecordingForTesting => _recordForTesting;

  /// Unmodifiable snapshot of navigation calls recorded during test mode.
  List<AppNavigationRecord> get recordedNavigations =>
      List.unmodifiable(_recordedNavigations);

  /// Enables (or disables) in-memory recording of navigation calls for unit tests.
  void setTestRecording({bool enabled = true, bool clear = true}) {
    _recordForTesting = enabled;
    if (clear) {
      _recordedNavigations.clear();
    }
  }

  /// Clears captured navigation records without changing recording mode.
  void clearRecordedNavigations() => _recordedNavigations.clear();

  void _record(
    String action, {
    Type? pageType,
    String? routeName,
    Object? arguments,
    Map<String, String>? parameters,
    Object? result,
  }) {
    if (!_recordForTesting) return;
    _recordedNavigations.add(
      AppNavigationRecord(
        action: action,
        pageType: pageType,
        routeName: routeName,
        arguments: arguments,
        parameters: parameters == null ? null : Map.unmodifiable(parameters),
        result: result,
      ),
    );
  }

  /// Current route parameters (e.g. from `/user/:id` or query parameters).
  Map<String, String> get parameters => Map.unmodifiable(_parameters);

  /// Sets the active route parameters.
  void setParameters(Map<String, String> params) {
    _parameters = params;
  }

  /// Gets the current arguments passed to the active route.
  dynamic get currentArguments {
    if (_observer._routeStack.isNotEmpty) {
      return _observer.currentArguments;
    }
    return _fallbackArgumentsStack.isEmpty
        ? null
        : _fallbackArgumentsStack.last;
  }

  /// Retrieves the current [BuildContext] from the root navigator, if mounted.
  BuildContext? get currentContext => navigatorKey.currentContext;

  /// Retrieves the current [NavigatorState] from the root navigator.
  NavigatorState? get currentState => navigatorKey.currentState;

  /// Whether the navigator can currently pop a route.
  bool get canPop => currentState?.canPop() ?? false;

  /// Pushes a new [page] onto the navigation stack without requiring [BuildContext].
  ///
  /// Optionally accepts [arguments] accessible via [App.arguments], and a
  /// custom [transition] style.
  ///
  /// Example:
  /// ```dart
  /// App.to(const ProfileScreen(), arguments: user);
  /// ```
  Future<T?> to<T>(
    dynamic page, {
    Object? arguments,
    Map<String, String>? parameters,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
    bool fullscreenDialog = false,
  }) {
    final Widget effectivePage =
        page is Widget Function() ? page() : page as Widget;
    if (parameters != null) setParameters(parameters);
    _record(
      'to',
      pageType: effectivePage.runtimeType,
      routeName: routeName,
      arguments: arguments,
      parameters: parameters,
    );

    final state = currentState;
    if (state == null) {
      if (_recordForTesting) {
        _fallbackArgumentsStack.add(arguments);
      } else {
        debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      }
      return Future.value(null);
    }

    _fallbackArgumentsStack.add(arguments);

    final route = AppRouteBuilder.buildRoute<T>(
      page: effectivePage,
      settings: RouteSettings(name: routeName, arguments: arguments),
      transition: transition,
      duration: duration ?? const Duration(milliseconds: 300),
      fullscreenDialog: fullscreenDialog,
    );

    return state.push<T>(route).then((res) {
      if (_observer._routeStack.isEmpty && _fallbackArgumentsStack.isNotEmpty) {
        _fallbackArgumentsStack.remove(arguments);
      }
      return res;
    });
  }

  /// Replaces the current route on the navigation stack with [page].
  ///
  /// Optionally returns [result] to the previous route and attaches [arguments].
  ///
  /// Example:
  /// ```dart
  /// App.off(const HomeScreen());
  /// ```
  Future<T?> off<T>(
    dynamic page, {
    Object? arguments,
    Map<String, String>? parameters,
    dynamic result,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
    bool fullscreenDialog = false,
  }) {
    final Widget effectivePage =
        page is Widget Function() ? page() : page as Widget;
    if (parameters != null) setParameters(parameters);
    _record(
      'off',
      pageType: effectivePage.runtimeType,
      routeName: routeName,
      arguments: arguments,
      parameters: parameters,
      result: result,
    );

    final state = currentState;
    if (state == null) {
      if (_recordForTesting) {
        if (_fallbackArgumentsStack.isNotEmpty) {
          _fallbackArgumentsStack.removeLast();
        }
        _fallbackArgumentsStack.add(arguments);
      } else {
        debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      }
      return Future.value(null);
    }

    if (_fallbackArgumentsStack.isNotEmpty) {
      _fallbackArgumentsStack.removeLast();
    }
    _fallbackArgumentsStack.add(arguments);

    final route = AppRouteBuilder.buildRoute<T>(
      page: effectivePage,
      settings: RouteSettings(name: routeName, arguments: arguments),
      transition: transition,
      duration: duration ?? const Duration(milliseconds: 300),
      fullscreenDialog: fullscreenDialog,
    );

    return state.pushReplacement<T, dynamic>(route, result: result).then((res) {
      if (_observer._routeStack.isEmpty && _fallbackArgumentsStack.isNotEmpty) {
        _fallbackArgumentsStack.remove(arguments);
      }
      return res;
    });
  }

  /// Clears the entire navigation stack and pushes [page] as the new root route.
  ///
  /// Ideal for authentication workflows (e.g., login, logout, onboarding completion).
  ///
  /// Example:
  /// ```dart
  /// App.offAll(const LoginScreen());
  /// ```
  Future<T?> offAll<T>(
    dynamic page, {
    Object? arguments,
    Map<String, String>? parameters,
    bool Function(Route<dynamic>)? predicate,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
    bool fullscreenDialog = false,
  }) {
    final Widget effectivePage =
        page is Widget Function() ? page() : page as Widget;
    if (parameters != null) setParameters(parameters);
    _record(
      'offAll',
      pageType: effectivePage.runtimeType,
      routeName: routeName,
      arguments: arguments,
      parameters: parameters,
    );

    final state = currentState;
    if (state == null) {
      if (_recordForTesting) {
        _fallbackArgumentsStack.clear();
        _fallbackArgumentsStack.add(arguments);
      } else {
        debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      }
      return Future.value(null);
    }

    _fallbackArgumentsStack.clear();
    _fallbackArgumentsStack.add(arguments);

    final route = AppRouteBuilder.buildRoute<T>(
      page: effectivePage,
      settings: RouteSettings(name: routeName, arguments: arguments),
      transition: transition,
      duration: duration ?? const Duration(milliseconds: 300),
      fullscreenDialog: fullscreenDialog,
    );

    return state.pushAndRemoveUntil<T>(
      route,
      predicate ?? (route) => false,
    );
  }

  /// Pushes a named route onto the navigation stack.
  Future<T?> toNamed<T>(
    String routeName, {
    Object? arguments,
    Map<String, String>? parameters,
    bool preventDuplicates = true,
  }) {
    if (preventDuplicates && currentRouteName == routeName) {
      return Future.value(null);
    }
    if (parameters != null) setParameters(parameters);
    _record(
      'toNamed',
      routeName: routeName,
      arguments: arguments,
      parameters: parameters,
    );

    final state = currentState;
    if (state == null) {
      if (_recordForTesting) {
        _fallbackArgumentsStack.add(arguments);
      } else {
        debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      }
      return Future.value(null);
    }
    _fallbackArgumentsStack.add(arguments);
    return state.pushNamed<T>(routeName, arguments: arguments).then((res) {
      if (_observer._routeStack.isEmpty && _fallbackArgumentsStack.isNotEmpty) {
        _fallbackArgumentsStack.remove(arguments);
      }
      return res;
    });
  }

  /// Replaces the current route with a named route.
  Future<T?> offNamed<T>(
    String routeName, {
    Object? arguments,
    Map<String, String>? parameters,
    dynamic result,
  }) {
    if (parameters != null) setParameters(parameters);
    _record(
      'offNamed',
      routeName: routeName,
      arguments: arguments,
      parameters: parameters,
      result: result,
    );

    final state = currentState;
    if (state == null) {
      if (_recordForTesting) {
        if (_fallbackArgumentsStack.isNotEmpty) {
          _fallbackArgumentsStack.removeLast();
        }
        _fallbackArgumentsStack.add(arguments);
      } else {
        debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      }
      return Future.value(null);
    }
    if (_fallbackArgumentsStack.isNotEmpty) {
      _fallbackArgumentsStack.removeLast();
    }
    _fallbackArgumentsStack.add(arguments);
    return state
        .pushReplacementNamed<T, dynamic>(
      routeName,
      arguments: arguments,
      result: result,
    )
        .then((res) {
      if (_observer._routeStack.isEmpty && _fallbackArgumentsStack.isNotEmpty) {
        _fallbackArgumentsStack.remove(arguments);
      }
      return res;
    });
  }

  /// Clears the entire navigation stack and pushes a named route.
  Future<T?> offAllNamed<T>(
    String routeName, {
    Object? arguments,
    Map<String, String>? parameters,
    bool Function(Route<dynamic>)? predicate,
  }) {
    if (parameters != null) setParameters(parameters);
    _record(
      'offAllNamed',
      routeName: routeName,
      arguments: arguments,
      parameters: parameters,
    );

    final state = currentState;
    if (state == null) {
      if (_recordForTesting) {
        _fallbackArgumentsStack.clear();
        _fallbackArgumentsStack.add(arguments);
      } else {
        debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      }
      return Future.value(null);
    }
    _fallbackArgumentsStack.clear();
    _fallbackArgumentsStack.add(arguments);
    return state.pushNamedAndRemoveUntil<T>(
      routeName,
      predicate ?? (route) => false,
      arguments: arguments,
    );
  }

  /// Pops the topmost route off the navigation stack.
  ///
  /// Optionally passes [result] back to the previous route caller.
  ///
  /// Example:
  /// ```dart
  /// App.back(updatedUser);
  /// ```
  void back<T>([T? result]) {
    _record('back', result: result);
    final state = currentState;
    if (state != null && state.canPop()) {
      state.pop<T>(result);
    }
  }

  /// Clears all navigation state, parameters, test recordings, and argument stacks.
  void reset() {
    _observer._routeStack.clear();
    _fallbackArgumentsStack.clear();
    _parameters = {};
    _recordForTesting = false;
    _recordedNavigations.clear();
  }
}

/// Declarative route specification for named page navigation.
class AppPage<T> {
  /// The route path (e.g. `'/home'`).
  final String name;

  /// Page builder widget.
  final Widget Function() page;

  /// Optional dependency binding executed before page mounting.
  final dynamic binding;

  /// Page transition style.
  final AppTransition transition;

  const AppPage({
    required this.name,
    required this.page,
    this.binding,
    this.transition = AppTransition.native,
  });
}
