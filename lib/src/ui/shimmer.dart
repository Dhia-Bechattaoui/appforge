import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Flow direction for the shimmer gradient sweep.
enum ShimmerDirection {
  /// Flow from left to right.
  ltr,

  /// Flow from right to left.
  rtl,

  /// Flow from top to bottom.
  ttb,

  /// Flow from bottom to top.
  btt,

  /// Automatically selects [rtl] in RTL directionality (e.g. Arabic)
  /// and [ltr] in LTR directionality.
  auto,
}

/// A GPU-accelerated, zero-dependency layout-adaptive shimmer animation engine.
///
/// Automatically inspects layout geometry (text lines, avatars, images, chips)
/// and renders exact matching skeleton bones over them without duplicate layout code.
///
/// Automatically adapts base and highlight colors to Light/Dark mode and supports
/// directionality-aware shimmering in Arabic / RTL layouts.
///
/// ```dart
/// // Shimmer real UI directly:
/// MyProfileCard(user: user).shimmer(enabled: isLoading);
///
/// // Or use root widget:
/// AppShimmer(
///   enabled: isLoading,
///   child: MyProfileCard(user: user),
/// );
/// ```
class AppShimmer extends StatefulWidget {
  /// The widget over which the shimmer gradient is drawn.
  final Widget child;

  /// Background tone of the skeleton placeholder.
  /// If null, automatically derives from the ambient theme brightness.
  final Color? baseColor;

  /// Highlight sweep tone.
  /// If null, automatically derives from the ambient theme brightness.
  final Color? highlightColor;

  /// Direction of the sweeping gradient. Defaults to [ShimmerDirection.auto],
  /// which aligns with the reading direction in RTL/Arabic layouts.
  final ShimmerDirection direction;

  /// Total duration of one full sweep cycle. Defaults to 1500ms.
  final Duration duration;

  /// Whether the shimmer animation is active. When false, renders [child] normally without animation.
  final bool enabled;

  /// Loop count before stopping. `null` loops indefinitely.
  final int? loop;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.direction = ShimmerDirection.auto,
    this.duration = const Duration(milliseconds: 1500),
    this.enabled = true,
    this.loop,
  });

  /// Pre-built rounded rectangle placeholder skeleton.
  static Widget box({
    Key? key,
    double? width,
    double? height,
    double borderRadius = 8,
    Color? baseColor,
    Color? highlightColor,
    ShimmerDirection direction = ShimmerDirection.auto,
    Duration duration = const Duration(milliseconds: 1500),
    bool enabled = true,
  }) {
    return AppShimmer(
      key: key,
      baseColor: baseColor,
      highlightColor: highlightColor,
      direction: direction,
      duration: duration,
      enabled: enabled,
      child: Container(
        width: width,
        height: height ?? 16,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  /// Pre-built circular placeholder skeleton (ideal for avatars and icons).
  static Widget circle({
    Key? key,
    double radius = 24,
    Color? baseColor,
    Color? highlightColor,
    ShimmerDirection direction = ShimmerDirection.auto,
    Duration duration = const Duration(milliseconds: 1500),
    bool enabled = true,
  }) {
    return AppShimmer(
      key: key,
      baseColor: baseColor,
      highlightColor: highlightColor,
      direction: direction,
      duration: duration,
      enabled: enabled,
      child: Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// Pre-built multi-line text skeleton.
  static Widget text({
    Key? key,
    double? width,
    double height = 12,
    int lines = 1,
    double spacing = 8,
    double borderRadius = 4,
    Color? baseColor,
    Color? highlightColor,
    ShimmerDirection direction = ShimmerDirection.auto,
    Duration duration = const Duration(milliseconds: 1500),
    bool enabled = true,
  }) {
    if (lines <= 1) {
      return box(
        key: key,
        width: width,
        height: height,
        borderRadius: borderRadius,
        baseColor: baseColor,
        highlightColor: highlightColor,
        direction: direction,
        duration: duration,
        enabled: enabled,
      );
    }

    return AppShimmer(
      key: key,
      baseColor: baseColor,
      highlightColor: highlightColor,
      direction: direction,
      duration: duration,
      enabled: enabled,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(lines, (index) {
          final isLast = index == lines - 1;
          final lineWidth = isLast && width != null ? width * 0.65 : width;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : spacing),
            child: Container(
              width: lineWidth,
              height: height,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Pre-built standard mobile ListTile skeleton with leading avatar and title/subtitle.
  static Widget listTile({
    Key? key,
    bool hasLeading = true,
    bool hasTrailing = false,
    double leadingRadius = 22,
    int subtitleLines = 1,
    Color? baseColor,
    Color? highlightColor,
    ShimmerDirection direction = ShimmerDirection.auto,
    Duration duration = const Duration(milliseconds: 1500),
    bool enabled = true,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
  }) {
    return AppShimmer(
      key: key,
      baseColor: baseColor,
      highlightColor: highlightColor,
      direction: direction,
      duration: duration,
      enabled: enabled,
      child: Padding(
        padding: padding,
        child: Row(
          children: [
            if (hasLeading) ...[
              Container(
                width: leadingRadius * 2,
                height: leadingRadius * 2,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
            ],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  if (subtitleLines > 0) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 140,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (hasTrailing) ...[
              const SizedBox(width: 14),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Pre-built card placeholder skeleton with image banner and text content.
  static Widget card({
    Key? key,
    double? width,
    double? height,
    double imageHeight = 140,
    double borderRadius = 12,
    Color? baseColor,
    Color? highlightColor,
    ShimmerDirection direction = ShimmerDirection.auto,
    Duration duration = const Duration(milliseconds: 1500),
    bool enabled = true,
  }) {
    return AppShimmer(
      key: key,
      baseColor: baseColor,
      highlightColor: highlightColor,
      direction: direction,
      duration: duration,
      enabled: enabled,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: imageHeight,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(borderRadius),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 160,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _loopCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);

    if (widget.loop != null) {
      _controller.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _loopCount++;
          if (widget.loop != null && _loopCount >= widget.loop!) {
            _controller.stop();
          } else {
            _controller.forward(from: 0.0);
          }
        }
      });
    }

    if (widget.enabled) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (widget.loop != null) {
      _controller.forward(from: 0.0);
    } else {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(AppShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.duration != oldWidget.duration) {
      _controller.duration = widget.duration;
    }
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _startAnimation();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC));

    final textDir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final effectiveDir = widget.direction == ShimmerDirection.auto
        ? (textDir == TextDirection.rtl
            ? ShimmerDirection.rtl
            : ShimmerDirection.ltr)
        : widget.direction;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return _ShimmerRenderWidget(
          enabled: widget.enabled,
          baseColor: base,
          highlightColor: highlight,
          progress: _controller.value,
          direction: effectiveDir,
          child: child!,
        );
      },
    );
  }
}

/// Helper creating a sweeping LinearGradient shader across [bounds].
Shader createShimmerShader({
  required Rect bounds,
  required double progress,
  required Color baseColor,
  required Color highlightColor,
  required ShimmerDirection direction,
}) {
  Alignment begin;
  Alignment end;

  // Linear translation offset from -1.0 to 2.0 to ensure complete traversal
  final double dx = (progress * 3.0) - 1.0;

  switch (direction) {
    case ShimmerDirection.ltr:
      begin = Alignment(dx - 1.0, 0.0);
      end = Alignment(dx + 1.0, 0.0);
      break;
    case ShimmerDirection.rtl:
      final double rdx = (1.0 - progress) * 3.0 - 1.0;
      begin = Alignment(rdx + 1.0, 0.0);
      end = Alignment(rdx - 1.0, 0.0);
      break;
    case ShimmerDirection.ttb:
      begin = Alignment(0.0, dx - 1.0);
      end = Alignment(0.0, dx + 1.0);
      break;
    case ShimmerDirection.btt:
      final double rdy = (1.0 - progress) * 3.0 - 1.0;
      begin = Alignment(0.0, rdy + 1.0);
      end = Alignment(0.0, rdy - 1.0);
      break;
    case ShimmerDirection.auto:
      begin = Alignment(dx - 1.0, 0.0);
      end = Alignment(dx + 1.0, 0.0);
      break;
  }

  return LinearGradient(
    begin: begin,
    end: end,
    colors: [baseColor, highlightColor, baseColor],
    stops: const [0.0, 0.5, 1.0],
  ).createShader(bounds);
}

/// Representation of a skeleton placeholder bone extracted automatically from layout.
class _SkeletonBone {
  final RRect? rrect;
  final Offset? circleCenter;
  final double? circleRadius;

  _SkeletonBone.rrect(this.rrect)
      : circleCenter = null,
        circleRadius = null;

  _SkeletonBone.circle({required this.circleCenter, required this.circleRadius})
      : rrect = null;
}

/// Custom RenderWidget that inspects child layout and paints matching skeleton bones.
class _ShimmerRenderWidget extends SingleChildRenderObjectWidget {
  final bool enabled;
  final Color baseColor;
  final Color highlightColor;
  final double progress;
  final ShimmerDirection direction;

  const _ShimmerRenderWidget({
    required super.child,
    required this.enabled,
    required this.baseColor,
    required this.highlightColor,
    required this.progress,
    required this.direction,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderShimmer(
      enabled: enabled,
      baseColor: baseColor,
      highlightColor: highlightColor,
      progress: progress,
      direction: direction,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderShimmer renderObject,
  ) {
    renderObject
      ..enabled = enabled
      ..baseColor = baseColor
      ..highlightColor = highlightColor
      ..progress = progress
      ..direction = direction;
  }
}

class _RenderShimmer extends RenderProxyBox {
  bool _enabled;
  Color _baseColor;
  Color _highlightColor;
  double _progress;
  ShimmerDirection _direction;

  Path? _cachedBonesPath;
  Size? _cachedLayoutSize;

  _RenderShimmer({
    required bool enabled,
    required Color baseColor,
    required Color highlightColor,
    required double progress,
    required ShimmerDirection direction,
    RenderBox? child,
  })  : _enabled = enabled,
        _baseColor = baseColor,
        _highlightColor = highlightColor,
        _progress = progress,
        _direction = direction,
        super(child);

  void _invalidateBones() {
    _cachedBonesPath = null;
    _cachedLayoutSize = null;
  }

  @override
  void performLayout() {
    super.performLayout();
    _invalidateBones();
  }

  @override
  void markNeedsLayout() {
    _invalidateBones();
    super.markNeedsLayout();
  }

  @override
  void detach() {
    _invalidateBones();
    super.detach();
  }

  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _invalidateBones();
    markNeedsPaint();
  }

  set baseColor(Color value) {
    if (_baseColor == value) return;
    _baseColor = value;
    markNeedsPaint();
  }

  set highlightColor(Color value) {
    if (_highlightColor == value) return;
    _highlightColor = value;
    markNeedsPaint();
  }

  set progress(double value) {
    if (_progress == value) return;
    _progress = value;
    markNeedsPaint();
  }

  set direction(ShimmerDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_enabled || child == null) {
      super.paint(context, offset);
      return;
    }

    if (_cachedBonesPath == null || _cachedLayoutSize != size) {
      final bones = <_SkeletonBone>[];
      _collectBones(child!, Offset.zero, bones);

      if (bones.isEmpty) {
        // Fallback if no specific leaf elements found
        bones.add(_SkeletonBone.rrect(
          RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
        ));
      }

      final path = Path();
      for (final bone in bones) {
        if (bone.rrect != null) {
          path.addRRect(bone.rrect!);
        } else if (bone.circleCenter != null && bone.circleRadius != null) {
          path.addOval(Rect.fromCircle(
            center: bone.circleCenter!,
            radius: bone.circleRadius!,
          ));
        }
      }

      _cachedBonesPath = path;
      _cachedLayoutSize = size;
    }

    final shader = createShimmerShader(
      bounds: Offset.zero & size,
      progress: _progress,
      baseColor: _baseColor,
      highlightColor: _highlightColor,
      direction: _direction,
    );

    final paint = Paint()
      ..shader = shader
      ..style = PaintingStyle.fill;

    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    context.canvas.drawPath(_cachedBonesPath!, paint);
    context.canvas.restore();
  }

  void _collectBones(
    RenderObject node,
    Offset parentOffset,
    List<_SkeletonBone> bones,
  ) {
    Offset currentOffset = parentOffset;
    if (node.parentData is BoxParentData) {
      currentOffset += (node.parentData as BoxParentData).offset;
    }

    // 1. Text Paragraphs
    if (node is RenderParagraph) {
      final text = node.text.toPlainText();
      final isIcon = text.runes.length == 1 &&
          (node.text.style?.fontFamily?.contains('Icon') ?? false);

      if (isIcon) {
        bones.add(_SkeletonBone.circle(
          circleCenter:
              currentOffset + Offset(node.size.width / 2, node.size.height / 2),
          circleRadius: node.size.width / 2,
        ));
        return;
      }

      final boxes = node.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );

      if (boxes.isEmpty) {
        bones.add(_SkeletonBone.rrect(
          RRect.fromRectAndRadius(
            currentOffset & node.size,
            const Radius.circular(4),
          ),
        ));
      } else {
        for (final box in boxes) {
          final lineRect = Rect.fromLTRB(
            currentOffset.dx + box.left,
            currentOffset.dy + box.top + 1,
            currentOffset.dx + box.right,
            currentOffset.dy + box.bottom - 1,
          );
          bones.add(_SkeletonBone.rrect(
            RRect.fromRectAndRadius(
              lineRect,
              const Radius.circular(4),
            ),
          ));
        }
      }
      return;
    }

    // 2. Images
    if (node is RenderImage) {
      bones.add(_SkeletonBone.rrect(
        RRect.fromRectAndRadius(
          currentOffset & node.size,
          const Radius.circular(8),
        ),
      ));
      return;
    }

    // 3. Decorated Boxes with Circular Shape (e.g. CircleAvatars)
    if (node is RenderDecoratedBox) {
      final decoration = node.decoration;
      if (decoration is BoxDecoration) {
        if (decoration.shape == BoxShape.circle) {
          bones.add(_SkeletonBone.circle(
            circleCenter: currentOffset +
                Offset(node.size.width / 2, node.size.height / 2),
            circleRadius: node.size.width / 2,
          ));
          return;
        }
      }
    }

    // 4. Custom leaf boxes without children (e.g. Chips, small colored boxes)
    bool hasChildren = false;
    node.visitChildren((child) => hasChildren = true);
    if (!hasChildren &&
        node is RenderBox &&
        node.size.width > 0 &&
        node.size.height > 0) {
      bones.add(_SkeletonBone.rrect(
        RRect.fromRectAndRadius(
          currentOffset & node.size,
          const Radius.circular(6),
        ),
      ));
      return;
    }

    // Recursively walk children
    node.visitChildren((childNode) {
      _collectBones(childNode, currentOffset, bones);
    });
  }
}

/// Ergonomic extension to turn any widget into a shimmer placeholder.
extension AppShimmerExtension on Widget {
  /// Wraps this widget in an automatic, GPU-accelerated [AppShimmer] sweep.
  ///
  /// Automatically matches layout geometry (text lines, avatars, images, chips)
  /// and renders exact matching skeleton bones over them without duplicate layout code!
  Widget shimmer({
    Key? key,
    bool enabled = true,
    Color? baseColor,
    Color? highlightColor,
    ShimmerDirection direction = ShimmerDirection.auto,
    Duration duration = const Duration(milliseconds: 1500),
    int? loop,
  }) {
    return AppShimmer(
      key: key,
      enabled: enabled,
      baseColor: baseColor,
      highlightColor: highlightColor,
      direction: direction,
      duration: duration,
      loop: loop,
      child: this,
    );
  }
}
