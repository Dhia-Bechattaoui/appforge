import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Screen dimension scaler for AppForge.
///
/// Adapts UI dimensions, font sizes, and radii across various screen form factors
/// relative to a baseline reference design size (default: 390x844).
class AppResponsive {
  AppResponsive._();

  /// Default baseline reference design size (modern mobile standard).
  static const Size defaultDesignSize = Size(390, 844);

  static Size _designSize = defaultDesignSize;
  static Size? _screenSize;
  static double _textScaleFactor = 1.0;
  static double _devicePixelRatio = 1.0;

  /// Reactive notifier that fires whenever screen metrics (size, orientation, ratio) change.
  static final ValueNotifier<Size> metricsNotifier =
      ValueNotifier<Size>(defaultDesignSize);

  /// The active baseline reference design size.
  static Size get designSize => _designSize;

  /// The detected device screen size.
  static Size get screenSize => _screenSize ?? _designSize;

  /// Active screen width.
  static double get screenWidth => screenSize.width;

  /// Active screen height.
  static double get screenHeight => screenSize.height;

  /// Active device pixel ratio.
  static double get devicePixelRatio => _devicePixelRatio;

  /// Whether the device is mobile (< 600 dp).
  static bool get isMobile => screenWidth < 600;

  /// Whether the device is tablet (>= 600 dp and < 1024 dp).
  static bool get isTablet => screenWidth >= 600 && screenWidth < 1024;

  /// Whether the device is desktop (>= 1024 dp).
  static bool get isDesktop => screenWidth >= 1024;

  /// Initializes or updates the responsive engine configuration.
  ///
  /// Example:
  /// ```dart
  /// AppResponsive.init(
  ///   designSize: const Size(390, 844),
  ///   screenSize: const Size(414, 896),
  /// );
  /// ```
  static void init({
    Size designSize = defaultDesignSize,
    Size? screenSize,
    double textScaleFactor = 1.0,
    double devicePixelRatio = 1.0,
  }) {
    _designSize = designSize;
    if (screenSize != null) {
      _screenSize = screenSize;
      metricsNotifier.value = screenSize;
    }
    _textScaleFactor = textScaleFactor;
    _devicePixelRatio = devicePixelRatio;
  }

  /// Synchronizes responsive metrics from the current [BuildContext].
  static void updateFromContext(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final scale = textScaler.scale(1.0);
    final ratio = MediaQuery.devicePixelRatioOf(context);

    final changed = _screenSize != size ||
        _devicePixelRatio != ratio ||
        _textScaleFactor != scale;

    _screenSize = size;
    _textScaleFactor = scale;
    _devicePixelRatio = ratio;

    if (changed) {
      metricsNotifier.value = size;
    }
  }

  /// Synchronizes responsive metrics from a [MediaQueryData] instance.
  static void updateFromData(MediaQueryData mediaQuery) {
    final size = mediaQuery.size;
    final scale = mediaQuery.textScaler.scale(1.0);
    final ratio = mediaQuery.devicePixelRatio;

    final changed = _screenSize != size ||
        _devicePixelRatio != ratio ||
        _textScaleFactor != scale;

    _screenSize = size;
    _textScaleFactor = scale;
    _devicePixelRatio = ratio;

    if (changed) {
      metricsNotifier.value = size;
    }
  }

  /// Scales a horizontal dimension [size] proportionally to screen width.
  static double scaleWidth(num size) {
    if (_screenSize == null) return size.toDouble();
    return size * (_screenSize!.width / _designSize.width);
  }

  /// Scales a vertical dimension [size] proportionally to screen height.
  static double scaleHeight(num size) {
    if (_screenSize == null) return size.toDouble();
    return size * (_screenSize!.height / _designSize.height);
  }

  /// Scales a corner radius [size] using the smaller scaling ratio to prevent distortion.
  static double scaleRadius(num size) {
    if (_screenSize == null) return size.toDouble();
    final scaleX = _screenSize!.width / _designSize.width;
    final scaleY = _screenSize!.height / _designSize.height;
    return size * math.min(scaleX, scaleY);
  }

  /// Scales a font size [size] proportionally to screen geometry without double-scaling.
  ///
  /// Flutter's [Text] widget inherently applies the system accessibility [TextScaler].
  /// Therefore, [scaleSp] scales strictly relative to design geometry and does not
  /// multiply by system text scale factor by default, preventing distorted text.
  ///
  /// Optional [maxScale] clamps the maximum expansion on tablets or desktop.
  /// Set [applySystemScale] to `true` only when rendering text outside of Flutter's
  /// [Text] widget (e.g. custom [Canvas] text painting).
  static double scaleSp(
    num size, {
    double? maxScale,
    bool applySystemScale = false,
    @Deprecated('Use applySystemScale instead. Will be removed in v1.0.0.')
    bool? obeySystemFontScale,
  }) {
    final baseScaled = scaleWidth(size);
    final shouldApplySystem = obeySystemFontScale ?? applySystemScale;
    final scaled =
        shouldApplySystem ? baseScaled * _textScaleFactor : baseScaled;

    if (maxScale != null && scaled > size * maxScale) {
      return (size * maxScale).toDouble();
    }
    return scaled;
  }

  /// Resets responsive scaler configuration to defaults (useful in tests).
  static void reset() {
    _designSize = defaultDesignSize;
    _screenSize = null;
    _textScaleFactor = 1.0;
    _devicePixelRatio = 1.0;
    metricsNotifier.value = defaultDesignSize;
  }
}
