import 'package:flutter/material.dart';
import '../core/app.dart';

/// Extension on [Widget] to provide automatic horizontal mirroring in Right-to-Left (RTL) layouts.
extension AppRtlMirrorExtension on Widget {
  /// Automatically mirrors this widget horizontally when active direction is Right-to-Left (RTL).
  ///
  /// Useful for directional navigation elements such as forward/back arrows,
  /// chevrons, and pagination buttons.
  ///
  /// If [context] is provided, uses [Directionality.maybeOf(context)].
  /// Otherwise, falls back to the global [App.isRtl].
  ///
  /// Example:
  /// ```dart
  /// const Icon(Icons.arrow_forward).autoMirror()
  /// ```
  Widget autoMirror([BuildContext? context]) {
    final isRtl = context != null
        ? Directionality.maybeOf(context) == TextDirection.rtl
        : App.isRtl;

    if (!isRtl) return this;
    return Transform.flip(flipX: true, child: this);
  }
}

/// Helper facade for directional navigation icons that mirror automatically in RTL layouts.
class AppIcons {
  AppIcons._();

  /// Forward arrow icon pointing Right (`->`) in LTR, and Left (`<-`) in RTL.
  static Widget arrowForward({
    BuildContext? context,
    double? size,
    Color? color,
    String? semanticLabel,
  }) {
    return Icon(
      Icons.arrow_forward,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    ).autoMirror(context);
  }

  /// Back arrow icon pointing Left (`<-`) in LTR, and Right (`->`) in RTL.
  static Widget arrowBack({
    BuildContext? context,
    double? size,
    Color? color,
    String? semanticLabel,
  }) {
    return Icon(
      Icons.arrow_back,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    ).autoMirror(context);
  }

  /// Forward chevron icon (`>`) in LTR, and (`<`) in RTL.
  static Widget chevronForward({
    BuildContext? context,
    double? size,
    Color? color,
    String? semanticLabel,
  }) {
    return Icon(
      Icons.chevron_right,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    ).autoMirror(context);
  }

  /// Backward chevron icon (`<`) in LTR, and (`>`) in RTL.
  static Widget chevronBack({
    BuildContext? context,
    double? size,
    Color? color,
    String? semanticLabel,
  }) {
    return Icon(
      Icons.chevron_left,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    ).autoMirror(context);
  }
}
