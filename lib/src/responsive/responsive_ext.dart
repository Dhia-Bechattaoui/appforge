import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'responsive_scaler.dart';

/// Extension on [num] to provide clean responsive scaling syntax (.w, .h, .sp, .r, .gapX, .gapY).
extension AppResponsiveNumExtension on num {
  /// Scales this number as a horizontal width relative to reference design width.
  ///
  /// Example:
  /// ```dart
  /// Container(width: 120.w)
  /// ```
  double get w => AppResponsive.scaleWidth(this);

  /// Scales this number as a vertical height relative to reference design height.
  ///
  /// Example:
  /// ```dart
  /// Container(height: 60.h)
  /// ```
  double get h => AppResponsive.scaleHeight(this);

  /// Scales this number as a font size relative to screen width and design geometry.
  ///
  /// Does not double-scale with system accessibility font scaling by default.
  ///
  /// Example:
  /// ```dart
  /// Text('Title', style: TextStyle(fontSize: 18.sp))
  /// ```
  double get sp => AppResponsive.scaleSp(this);

  /// Scales this number as a corner radius, maintaining proportional aspect.
  ///
  /// Example:
  /// ```dart
  /// BorderRadius.circular(16.r)
  /// ```
  double get r => AppResponsive.scaleRadius(this);

  /// Creates a horizontal [SizedBox] spacer with this width in logical pixels.
  ///
  /// Example:
  /// ```dart
  /// Row(children: [Text('A'), 12.gapX, Text('B')])
  /// ```
  Widget get gapX => SizedBox(width: toDouble());

  /// Creates a vertical [SizedBox] spacer with this height in logical pixels.
  ///
  /// Example:
  /// ```dart
  /// Column(children: [Text('A'), 16.gapY, Text('B')])
  /// ```
  Widget get gapY => SizedBox(height: toDouble());

  /// Creates a proportionally scaled horizontal [SizedBox] spacer.
  Widget get gapXScaled => SizedBox(width: w);

  /// Creates a proportionally scaled vertical [SizedBox] spacer.
  Widget get gapYScaled => SizedBox(height: h);
}

/// Extension on [BuildContext] for fast access to screen and media dimensions.
extension AppResponsiveContextExtension on BuildContext {
  /// Scales [size] proportionally to screen width, establishing an inherited dependency on screen size.
  double w(num size) =>
      size * (MediaQuery.sizeOf(this).width / AppResponsive.designSize.width);

  /// Scales [size] proportionally to screen height, establishing an inherited dependency on screen size.
  double h(num size) =>
      size * (MediaQuery.sizeOf(this).height / AppResponsive.designSize.height);

  /// Scales [size] as a corner radius, establishing an inherited dependency on screen size.
  double r(num size) {
    final mediaSize = MediaQuery.sizeOf(this);
    final scaleX = mediaSize.width / AppResponsive.designSize.width;
    final scaleY = mediaSize.height / AppResponsive.designSize.height;
    return size * math.min(scaleX, scaleY);
  }

  /// Scales [size] as a font size, establishing an inherited dependency on screen size without double-scaling.
  double sp(num size, {double? maxScale}) {
    final scaled = w(size);
    if (maxScale != null && scaled > size * maxScale) {
      return (size * maxScale).toDouble();
    }
    return scaled;
  }

  /// Total width of the current screen.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Total height of the current screen.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Size of the current screen.
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Aspect ratio of the current screen.
  double get screenAspectRatio => MediaQuery.sizeOf(this).aspectRatio;

  /// Current device orientation.
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// Whether device is in landscape mode.
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;

  /// Whether device is in portrait mode.
  bool get isPortrait => MediaQuery.orientationOf(this) == Orientation.portrait;

  /// System screen padding (status bar, home bar, display notch).
  EdgeInsets get screenPadding => MediaQuery.paddingOf(this);

  /// System view insets (e.g., software keyboard).
  EdgeInsets get screenViewInsets => MediaQuery.viewInsetsOf(this);

  /// Top safe area padding / status bar height.
  double get statusBarHeight => MediaQuery.paddingOf(this).top;

  /// Bottom safe area padding / home indicator height.
  double get bottomBarHeight => MediaQuery.paddingOf(this).bottom;

  /// Whether the on-screen keyboard is currently visible.
  bool get isKeyboardVisible => MediaQuery.viewInsetsOf(this).bottom > 0;

  /// Height of the on-screen keyboard if visible.
  double get keyboardHeight => MediaQuery.viewInsetsOf(this).bottom;

  /// Whether the screen qualifies as a mobile device (< 600 dp).
  bool get isMobile => MediaQuery.sizeOf(this).width < 600;

  /// Whether the screen qualifies as a tablet (>= 600 dp and < 1024 dp).
  bool get isTablet {
    final width = MediaQuery.sizeOf(this).width;
    return width >= 600 && width < 1024;
  }

  /// Whether the screen qualifies as a desktop (>= 1024 dp).
  bool get isDesktop => MediaQuery.sizeOf(this).width >= 1024;
}
