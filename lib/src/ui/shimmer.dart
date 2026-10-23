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
      _loopCount = 0;
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Tones derived from ambient theme brightness so bones fully conceal content.
    final base = widget.baseColor ??
        Color.alphaBlend(
          scheme.onSurface.withValues(alpha: isDark ? 0.16 : 0.09),
          scheme.surface,
        );
    final highlight = widget.highlightColor ??
        Color.alphaBlend(
          scheme.onSurface.withValues(alpha: isDark ? 0.26 : 0.03),
          scheme.surface,
        );

    final textDir = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final effectiveDir = widget.direction == ShimmerDirection.auto
        ? (textDir == TextDirection.rtl
            ? ShimmerDirection.rtl
            : ShimmerDirection.ltr)
        : widget.direction;

    // DefaultTextStyle and IconTheme make text and icons invisible during shimmer,
    // while keeping exact dimensions, baseline, and wrapping.
    final themedChild = widget.enabled
        ? DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.transparent),
            child: IconTheme.merge(
              data: const IconThemeData(color: Colors.transparent),
              child: widget.child,
            ),
          )
        : widget.child;

    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: themedChild),
      builder: (context, child) {
        return _ShimmerRenderWidget(
          enabled: widget.enabled,
          baseColor: base,
          highlightColor: highlight,
          progress: _controller.value,
          direction: effectiveDir,
          textDirection: textDir,
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

/// Outcome of skeletonizing a render subtree.
class _SkeletonScan {
  const _SkeletonScan.content()
      : hasContent = true,
        placeholders = const <Path>[];

  const _SkeletonScan.pending(this.placeholders) : hasContent = false;

  static const _SkeletonScan empty = _SkeletonScan.pending(<Path>[]);

  final bool hasContent;

  /// Placeholder shapes in shimmer-local coordinates awaiting emission.
  final List<Path> placeholders;
}

/// Walks a laid-out render tree and derives skeleton bone geometry.
///
/// Composition model:
/// * **Content** (paragraphs, icons, images, circular avatars, leaf controls)
///   is concealed by bones matching its exact geometry.
/// * **Surfaces** (`Card`, `Material`, decorated / coloured `Container`s) that
///   host content are left untouched so the real structural silhouette,
///   elevation, borders, and gradients remain visible while loading.
/// * A painted surface hosting **no** content (e.g. a grey placeholder box)
///   becomes a bone itself, using its own shape (rounded, stadium, circle...).
class _SkeletonCollector {
  _SkeletonCollector(this.textDirection);

  final TextDirection textDirection;
  final Path bones = Path();

  /// Whether a scrollable viewport was encountered. Viewport scrolling does not
  /// relayout ancestors, so such geometry must be re-derived every frame.
  bool encounteredViewport = false;

  _SkeletonScan scan(RenderObject node, Matrix4 transform) {
    if (node is RenderBox) {
      if (!node.hasSize || node.size.isEmpty) return _SkeletonScan.empty;
      if (node is RenderOffstage && node.offstage) return _SkeletonScan.empty;

      if (node is RenderParagraph) {
        _emitParagraph(node, transform);
        return const _SkeletonScan.content();
      }

      if (node is RenderImage) {
        _emitLocal(
          Path()
            ..addRRect(RRect.fromRectAndRadius(
              Offset.zero & node.size,
              const Radius.circular(8),
            )),
          transform,
        );
        return const _SkeletonScan.content();
      }

      final decoration = node is RenderDecoratedBox ? node.decoration : null;
      if (decoration is BoxDecoration && decoration.shape == BoxShape.circle) {
        _emitLocal(
          Path()
            ..addOval(Rect.fromCircle(
              center: node.size.center(Offset.zero),
              radius: node.size.shortestSide / 2,
            )),
          transform,
        );
        return const _SkeletonScan.content();
      }
    }

    if (node is RenderViewportBase) encounteredViewport = true;

    var hasChildren = false;
    var anyContent = false;
    final pending = <Path>[];

    node.visitChildren((child) {
      hasChildren = true;
      if (!node.paintsChild(child)) return;
      final childTransform = transform.clone();
      node.applyPaintTransform(child, childTransform);
      final result = scan(child, childTransform);
      if (result.hasContent) {
        anyContent = true;
      } else {
        pending.addAll(result.placeholders);
      }
    });

    if (anyContent) {
      // Placeholder siblings of real content are concealed individually.
      _emitAll(pending);
      return const _SkeletonScan.content();
    }

    if (node is! RenderBox || !_paintsOwnSurface(node, hasChildren)) {
      // Transparent layout node: defer placeholders to the enclosing surface.
      return _SkeletonScan.pending(pending);
    }

    if (pending.isNotEmpty) {
      // A visible surface hosting placeholders: keep the surface, bone the inside.
      _emitAll(pending);
      return const _SkeletonScan.content();
    }

    // A painted node with nothing inside is itself a placeholder.
    return _SkeletonScan.pending(
        <Path>[_transformed(_shapeOf(node), transform)]);
  }

  /// Emits the deferred placeholders of the root scan, or a full-bounds bone
  /// when the subtree paints nothing recognisable.
  void finish(_SkeletonScan root, Size size) {
    if (root.hasContent) return;
    if (root.placeholders.isNotEmpty) {
      _emitAll(root.placeholders);
      return;
    }
    bones.addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
    );
  }

  void _emitParagraph(RenderParagraph node, Matrix4 transform) {
    final local = Path();
    final text = node.text.toPlainText();
    final isIcon = text.runes.length == 1 &&
        (node.text.style?.fontFamily?.contains('Icon') ?? false);

    if (isIcon) {
      local.addRRect(RRect.fromRectAndRadius(
        Offset.zero & node.size,
        Radius.circular(node.size.shortestSide / 4),
      ));
    } else {
      final boxes = node.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.length),
      );
      if (boxes.isEmpty) {
        local.addRRect(RRect.fromRectAndRadius(
          Offset.zero & node.size,
          const Radius.circular(4),
        ));
      } else {
        for (final box in boxes) {
          local.addRRect(
            RRect.fromRectAndRadius(
              box.toRect().inflate(1.0),
              const Radius.circular(4),
            ),
          );
        }
      }
    }
    _emitLocal(local, transform);
  }

  static bool _paintsOwnSurface(RenderBox node, bool hasChildren) {
    if (node is RenderDecoratedBox) return true;
    if (node is RenderPhysicalShape) {
      return node.color.a > 0 || node.elevation > 0;
    }
    if (node is RenderPhysicalModel) {
      return node.color.a > 0 || node.elevation > 0;
    }
    if (node is RenderCustomPaint) {
      return node.painter != null || node.foregroundPainter != null;
    }
    if (node is RenderPointerListener ||
        node is RenderMouseRegion ||
        node is RenderMetaData ||
        node is RenderSemanticsGestureHandler ||
        node is RenderTapRegion) {
      return false;
    }
    if (node is RenderProxyBoxWithHitTestBehavior) return true;
    if (hasChildren) return false;
    if (node is RenderProxyBox ||
        node is RenderShiftedBox ||
        node is ContainerRenderObjectMixin) {
      return false;
    }
    return true;
  }

  Path _shapeOf(RenderBox node) {
    final rect = Offset.zero & node.size;

    if (node is RenderPhysicalShape) {
      return node.clipper?.getClip(node.size) ?? (Path()..addRect(rect));
    }
    if (node is RenderPhysicalModel) {
      if (node.shape == BoxShape.circle) {
        return Path()
          ..addOval(Rect.fromCircle(
            center: rect.center,
            radius: rect.shortestSide / 2,
          ));
      }
      final radius = node.borderRadius;
      if (radius != null && radius != BorderRadius.zero) {
        return Path()..addRRect(radius.toRRect(rect));
      }
    }
    if (node is RenderDecoratedBox) {
      final decoration = node.decoration;
      final isPlainRect = decoration is BoxDecoration &&
          decoration.borderRadius == null &&
          decoration.shape == BoxShape.rectangle;
      if (!isPlainRect) {
        try {
          return decoration.getClipPath(rect, textDirection);
        } on UnsupportedError {
          // Decoration does not expose a clip path; fall through.
        }
      }
    }
    return Path()
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));
  }

  Path _transformed(Path local, Matrix4 transform) {
    final translation = MatrixUtils.getAsTranslation(transform);
    if (translation != null) return local.shift(translation);
    return local.transform(transform.storage);
  }

  void _emitLocal(Path local, Matrix4 transform) {
    bones.addPath(_transformed(local, transform), Offset.zero);
  }

  void _emitAll(List<Path> paths) {
    for (final path in paths) {
      bones.addPath(path, Offset.zero);
    }
  }
}

/// Custom RenderWidget that inspects child layout and paints matching skeleton bones.
class _ShimmerRenderWidget extends SingleChildRenderObjectWidget {
  final bool enabled;
  final Color baseColor;
  final Color highlightColor;
  final double progress;
  final ShimmerDirection direction;
  final TextDirection textDirection;

  const _ShimmerRenderWidget({
    required super.child,
    required this.enabled,
    required this.baseColor,
    required this.highlightColor,
    required this.progress,
    required this.direction,
    required this.textDirection,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderShimmer(
      enabled: enabled,
      baseColor: baseColor,
      highlightColor: highlightColor,
      progress: progress,
      direction: direction,
      textDirection: textDirection,
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
      ..direction = direction
      ..textDirection = textDirection;
  }
}

class _RenderShimmer extends RenderProxyBox {
  bool _enabled;
  Color _baseColor;
  Color _highlightColor;
  double _progress;
  ShimmerDirection _direction;
  TextDirection _textDirection;

  Path? _cachedBones;
  bool _volatileGeometry = false;

  _RenderShimmer({
    required bool enabled,
    required Color baseColor,
    required Color highlightColor,
    required double progress,
    required ShimmerDirection direction,
    required TextDirection textDirection,
    RenderBox? child,
  })  : _enabled = enabled,
        _baseColor = baseColor,
        _highlightColor = highlightColor,
        _progress = progress,
        _direction = direction,
        _textDirection = textDirection,
        super(child);

  void _invalidateBones() {
    _cachedBones = null;
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
    markNeedsSemanticsUpdate();
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

  set textDirection(TextDirection value) {
    if (_textDirection == value) return;
    _textDirection = value;
    _invalidateBones();
    markNeedsPaint();
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (_enabled) return size.contains(position);
    return super.hitTest(result, position: position);
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (_enabled) return;
    super.visitChildrenForSemantics(visitor);
  }

  Path _deriveBones() {
    final collector = _SkeletonCollector(_textDirection);
    final transform = Matrix4.identity();
    applyPaintTransform(child!, transform);
    final root = collector.scan(child!, transform);
    collector.finish(root, size);
    _volatileGeometry = collector.encounteredViewport;
    return collector.bones;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // 1. Real tree: surfaces, cards, elevation, borders, gradients.
    super.paint(context, offset);
    if (!_enabled || child == null) return;

    // 2. Opaque bones concealing content, swept by the shimmer gradient.
    if (_cachedBones == null || _volatileGeometry) {
      _cachedBones = _deriveBones();
    }

    final paint = Paint()
      ..shader = createShimmerShader(
        bounds: Offset.zero & size,
        progress: _progress,
        baseColor: _baseColor,
        highlightColor: _highlightColor,
        direction: _direction,
      )
      ..style = PaintingStyle.fill;

    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(_cachedBones!, paint);
    canvas.restore();
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
