import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as m;
import 'navigator.dart';

/// Semantic types for AppForge context-free snackbars.
enum AppSnackbarType {
  /// Success notification (green accent).
  success,

  /// Error or failure notification (red accent).
  error,

  /// Warning notification (amber accent).
  warning,

  /// Informational notification (blue accent).
  info,
}

/// Context-free overlay and feedback engine for AppForge.
///
/// Handles snackbars, modal dialogs, bottom sheets, and loading spinners
/// across async gaps without requiring a [BuildContext].
class AppOverlay {
  AppOverlay._();

  static final AppOverlay instance = AppOverlay._();

  /// Global key bound to the root [ScaffoldMessengerState].
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _isLoadingOpen = false;
  Route<void>? _loadingRoute;

  /// Whether the global loading overlay is currently active on screen.
  bool get isLoadingOpen => _isLoadingOpen;

  /// Displays a floating, styled snackbar notification from anywhere without [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.snackbar('نجاح', 'تم حفظ التغييرات بنجاح', type: AppSnackbarType.success);
  /// ```
  void showSnackbar(
    String title,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    Widget? icon,
    VoidCallback? onTap,
    Color? backgroundColor,
    Color? textColor,
  }) {
    final state = scaffoldMessengerKey.currentState;
    if (state == null) {
      debugPrint(
          '[AppForge] Cannot show snackbar: ScaffoldMessengerState is null.');
      return;
    }

    state.clearSnackBars();

    final palette = _resolveSnackbarPalette(type);
    final effectiveBg = backgroundColor ?? palette.background;
    final effectiveFg = textColor ?? palette.foreground;
    final effectiveIcon = icon ?? palette.icon;

    final snackBar = SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      elevation: 4.0,
      backgroundColor: effectiveBg,
      margin: const EdgeInsets.all(16.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: palette.border, width: 1.0),
      ),
      content: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            effectiveIcon,
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (title.isNotEmpty)
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.0,
                        color: effectiveFg,
                      ),
                    ),
                  if (title.isNotEmpty && message.isNotEmpty)
                    const SizedBox(height: 2.0),
                  if (message.isNotEmpty)
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: effectiveFg.withValues(alpha: 0.9),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    state.showSnackBar(snackBar);
  }

  /// Displays a modal dialog from anywhere without [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.dialog(const LogoutConfirmationDialog());
  /// ```
  Future<T?> showDialog<T>(
    Widget dialog, {
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
  }) {
    final context = AppNavigator.instance.currentContext;
    if (context == null) {
      debugPrint('[AppForge] Cannot show dialog: currentContext is null.');
      return Future.value(null);
    }

    return m.showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black54,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      builder: (_) => dialog,
    );
  }

  /// Displays a modal bottom sheet from anywhere without [BuildContext].
  ///
  /// Example:
  /// ```dart
  /// App.bottomSheet(const SelectLanguageSheet());
  /// ```
  Future<T?> showBottomSheet<T>(
    Widget bottomSheet, {
    bool isDismissible = true,
    Color? backgroundColor,
    double? elevation,
    bool enableDrag = true,
    bool isScrollControlled = false,
    Clip clipBehavior = Clip.antiAliasWithSaveLayer,
  }) {
    final context = AppNavigator.instance.currentContext;
    if (context == null) {
      debugPrint('[AppForge] Cannot show bottomSheet: currentContext is null.');
      return Future.value(null);
    }

    return m.showModalBottomSheet<T>(
      context: context,
      isDismissible: isDismissible,
      backgroundColor: backgroundColor,
      elevation: elevation,
      enableDrag: enableDrag,
      isScrollControlled: isScrollControlled,
      clipBehavior: clipBehavior,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (_) => bottomSheet,
    );
  }

  /// Displays a non-dismissible global loading overlay for asynchronous operations.
  ///
  /// Prevents duplicate loaders and guards against unwanted touches.
  ///
  /// Example:
  /// ```dart
  /// App.showLoading(message: 'جارٍ تسجيل الدخول...');
  /// await login();
  /// App.hideLoading();
  /// ```
  void showLoading({
    String? message,
    Widget? customIndicator,
  }) {
    if (_isLoadingOpen) return;

    final context = AppNavigator.instance.currentContext;
    if (context == null) {
      debugPrint(
          '[AppForge] Cannot show loading overlay: currentContext is null.');
      return;
    }

    _isLoadingOpen = true;

    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black38,
      useSafeArea: true,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                customIndicator ??
                    const CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                if (message != null && message.isNotEmpty) ...[
                  const SizedBox(height: 16.0),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    _loadingRoute = route;
    Navigator.of(context).push(route).then((_) {
      if (identical(_loadingRoute, route)) {
        _loadingRoute = null;
        _isLoadingOpen = false;
      }
    });
  }

  /// Dismisses the active global loading overlay safely without disturbing other dialogs.
  void hideLoading() {
    if (_isLoadingOpen) {
      _isLoadingOpen = false;
      final route = _loadingRoute;
      _loadingRoute = null;
      if (route != null && route.isActive) {
        route.navigator?.removeRoute(route);
      }
    }
  }

  _SnackbarPalette _resolveSnackbarPalette(AppSnackbarType type) {
    switch (type) {
      case AppSnackbarType.success:
        return const _SnackbarPalette(
          background: Color(0xFF1E3A2F),
          foreground: Color(0xFFE8F5E9),
          border: Color(0xFF2E7D32),
          icon: Icon(Icons.check_circle_rounded,
              color: Color(0xFF81C784), size: 24.0),
        );
      case AppSnackbarType.error:
        return const _SnackbarPalette(
          background: Color(0xFF3E1C1C),
          foreground: Color(0xFFFFEBEE),
          border: Color(0xFFC62828),
          icon: Icon(Icons.error_rounded, color: Color(0xFFE57373), size: 24.0),
        );
      case AppSnackbarType.warning:
        return const _SnackbarPalette(
          background: Color(0xFF3E2F1C),
          foreground: Color(0xFFFFF8E1),
          border: Color(0xFFEF6C00),
          icon:
              Icon(Icons.warning_rounded, color: Color(0xFFFFB74D), size: 24.0),
        );
      case AppSnackbarType.info:
        return const _SnackbarPalette(
          background: Color(0xFF1C2D3E),
          foreground: Color(0xFFE3F2FD),
          border: Color(0xFF1565C0),
          icon: Icon(Icons.info_rounded, color: Color(0xFF64B5F6), size: 24.0),
        );
    }
  }
}

class _SnackbarPalette {
  final Color background;
  final Color foreground;
  final Color border;
  final Widget icon;

  const _SnackbarPalette({
    required this.background,
    required this.foreground,
    required this.border,
    required this.icon,
  });
}
