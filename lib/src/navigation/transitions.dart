import 'package:flutter/material.dart';

/// Transition styles supported by AppForge context-free navigation.
enum AppTransition {
  /// Native platform transition (Cupertino on iOS, Material on Android).
  native,

  /// Direction-aware horizontal slide (slides from Right in LTR, from Left in RTL).
  slide,

  /// Smooth fade transition.
  fade,

  /// Centered scale-up transition.
  scale,

  /// Bottom-to-top modal slide transition.
  bottomToTop,

  /// Instant transition with zero animation.
  none,
}

/// Helper that builds a [Route] based on the selected [AppTransition] style.
class AppRouteBuilder {
  AppRouteBuilder._();

  /// Creates a route with [transition] and optional arguments attached.
  static Route<T> buildRoute<T>({
    required Widget page,
    RouteSettings? settings,
    AppTransition transition = AppTransition.native,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    if (transition == AppTransition.native) {
      return MaterialPageRoute<T>(
        builder: (_) => page,
        settings: settings,
      );
    }

    if (transition == AppTransition.none) {
      return PageRouteBuilder<T>(
        pageBuilder: (_, __, ___) => page,
        settings: settings,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      );
    }

    return PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      settings: settings,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final isRtl = Directionality.of(context) == TextDirection.rtl;

        switch (transition) {
          case AppTransition.slide:
            // BiDi-aware: In RTL, slide from Left (-1.0); in LTR, slide from Right (1.0)
            final startX = isRtl ? -1.0 : 1.0;
            final tween = Tween<Offset>(
              begin: Offset(startX, 0.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );

          case AppTransition.fade:
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );

          case AppTransition.scale:
            return ScaleTransition(
              scale: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutBack,
              ),
              child: child,
            );

          case AppTransition.bottomToTop:
            final tween = Tween<Offset>(
              begin: const Offset(0.0, 1.0),
              end: Offset.zero,
            ).chain(CurveTween(curve: Curves.easeOutCubic));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );

          case AppTransition.native:
          case AppTransition.none:
            return child;
        }
      },
    );
  }
}
