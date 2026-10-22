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

  final List<Object?> _fallbackArgumentsStack = [];

  /// Gets the current arguments passed to the active route.
  Object? get currentArguments {
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
    Widget page, {
    Object? arguments,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
  }) {
    final state = currentState;
    if (state == null) {
      debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      return Future.value(null);
    }

    _fallbackArgumentsStack.add(arguments);

    final route = AppRouteBuilder.buildRoute<T>(
      page: page,
      settings: RouteSettings(name: routeName, arguments: arguments),
      transition: transition,
      duration: duration ?? const Duration(milliseconds: 300),
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
  Future<T?> off<T, TO>(
    Widget page, {
    Object? arguments,
    TO? result,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
  }) {
    final state = currentState;
    if (state == null) {
      debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      return Future.value(null);
    }

    if (_fallbackArgumentsStack.isNotEmpty) {
      _fallbackArgumentsStack.removeLast();
    }
    _fallbackArgumentsStack.add(arguments);

    final route = AppRouteBuilder.buildRoute<T>(
      page: page,
      settings: RouteSettings(name: routeName, arguments: arguments),
      transition: transition,
      duration: duration ?? const Duration(milliseconds: 300),
    );

    return state.pushReplacement<T, TO>(route, result: result).then((res) {
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
    Widget page, {
    Object? arguments,
    bool Function(Route<dynamic>)? predicate,
    AppTransition transition = AppTransition.native,
    Duration? duration,
    String? routeName,
  }) {
    final state = currentState;
    if (state == null) {
      debugPrint('[AppForge] Cannot navigate: NavigatorState is null.');
      return Future.value(null);
    }

    _fallbackArgumentsStack.clear();
    _fallbackArgumentsStack.add(arguments);

    final route = AppRouteBuilder.buildRoute<T>(
      page: page,
      settings: RouteSettings(name: routeName, arguments: arguments),
      transition: transition,
      duration: duration ?? const Duration(milliseconds: 300),
    );

    return state.pushAndRemoveUntil<T>(
      route,
      predicate ?? (route) => false,
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
    final state = currentState;
    if (state != null && state.canPop()) {
      state.pop<T>(result);
    }
  }

  /// Clears all navigation state and argument stacks.
  void reset() {
    _observer._routeStack.clear();
    _fallbackArgumentsStack.clear();
  }
}
