import 'package:flutter/widgets.dart';

/// General context utilities for focus management and navigation shorthands.
extension AppGeneralContextExtension on BuildContext {
  /// Unfocuses the current focus scope, dismissing the on-screen keyboard.
  ///
  /// Example:
  /// ```dart
  /// context.unfocus();
  /// ```
  void unfocus() {
    FocusScope.of(this).unfocus();
  }

  /// Requests focus for [node], or moves focus to the primary focus scope.
  void requestFocus([FocusNode? node]) {
    if (node != null) {
      FocusScope.of(this).requestFocus(node);
    } else {
      FocusScope.of(this).requestFocus();
    }
  }

  /// Whether the navigator associated with this context can pop.
  bool get canPop => Navigator.of(this).canPop();

  /// Pops the current route from this context's navigator.
  void pop<T>([T? result]) {
    Navigator.of(this).pop<T>(result);
  }
}
