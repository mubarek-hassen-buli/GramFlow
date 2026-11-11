import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:gramx/core/l10n/app_strings.dart';

/// Static vector path definitions extracted from `assets/brand/GramFlow-Loader.svg`.
///
/// The canvas viewBox is 500 × 500. The paths represent the GramFlow squircle
/// and inner flow glyph.
abstract final class GramFlowPathData {
  /// Base canvas size as defined in the SVG's viewBox.
  static const Size viewBox = Size(500, 500);

  /// Bounding rect of the mark inside the 500 × 500 canvas.
  static const Rect bounds = Rect.fromLTRB(100.6, 96.8, 399.5, 400.8);

  /// Center point of the mark.
  static const Offset center = Offset(250.0, 250.0);

  /// Outer squircle path.
  static final Path outerPath = _buildOuterPath();

  /// Inner flow symbol path.
  static final Path innerPath = _buildInnerPath();

  /// Combined even-odd path for the solid fill.
  static final Path fillPath = _buildFillPath();

  /// Path metrics for path extraction and trim animations.
  static final ui.PathMetric outerMetric = outerPath.computeMetrics().first;
  static final ui.PathMetric innerMetric = innerPath.computeMetrics().first;

  static final double outerLength = outerMetric.length;
  static final double innerLength = innerMetric.length;

  static Path _buildOuterPath() {
    final p = Path();
    p.moveTo(158.74, 100.68);
    p.cubicTo(205.4, 99.63, 252.19, 100.59, 298.86, 100.59);
    p.cubicTo(321.5, 100.59, 348.24, 96.85, 368.59, 108.37);
    p.cubicTo(384.21, 117.21, 395.25, 132.92, 398.5, 150.49);
    p.cubicTo(400.72, 162.49, 399.4, 175.75, 399.34, 187.9);
    p.cubicTo(399.14, 231.89, 399.48, 275.88, 399.35, 319.86);
    p.cubicTo(399.27, 346.67, 399.48, 368.59, 376.26, 386.53);
    p.cubicTo(359.05, 399.83, 342.02, 399.34, 321.23, 399.32);
    p.cubicTo(305.71, 399.3, 290.18, 399.3, 274.66, 399.22);
    p.cubicTo(245.74, 399.07, 216.81, 399.07, 187.9, 399.29);
    p.cubicTo(175.6, 399.38, 162.17, 400.79, 150.03, 398.5);
    p.cubicTo(132.95, 395.29, 116.93, 384.31, 108.48, 368.94);
    p.cubicTo(96.81, 347.71, 100.66, 319.29, 100.66, 295.66);
    p.cubicTo(100.66, 281.96, 100.73, 268.26, 100.66, 254.57);
    p.cubicTo(100.54, 232.19, 100.7, 209.82, 100.63, 187.44);
    p.cubicTo(100.59, 173.93, 99.01, 159.13, 102.39, 145.94);
    p.cubicTo(108.87, 120.62, 132.55, 101.27, 158.74, 100.68);
    p.close();
    return p;
  }

  static Path _buildInnerPath() {
    final p = Path();
    p.moveTo(249.78, 156.93);
    p.cubicTo(241.61, 156.81, 233.18, 158.7, 225.32, 160.66);
    p.cubicTo(216.88, 162.75, 208.39, 165.57, 200.89, 170.09);
    p.cubicTo(165.41, 191.45, 162.83, 235.18, 165.62, 272.37);
    p.cubicTo(167.28, 294.48, 172.99, 333.91, 198.06, 341.84);
    p.cubicTo(201.19, 342.83, 204.57, 343.2, 207.83, 343.15);
    p.cubicTo(238.21, 342.69, 240.83, 301.75, 257.38, 284.09);
    p.cubicTo(275.26, 265.02, 302.97, 271.56, 321.83, 249.44);
    p.cubicTo(326.43, 244.04, 330.09, 238.01, 332.39, 231.27);
    p.cubicTo(334.18, 226.02, 335.09, 220.39, 335.14, 214.84);
    p.cubicTo(335.52, 176.91, 297.26, 156.79, 263.41, 156.93);
    p.cubicTo(258.87, 156.93, 254.32, 156.93, 249.78, 156.93);
    p.close();
    return p;
  }

  static Path _buildFillPath() {
    final p = Path();
    p.fillType = PathFillType.evenOdd;
    p.addPath(outerPath, Offset.zero);
    p.addPath(innerPath, Offset.zero);
    return p;
  }
}

/// CustomPainter rendering the animated GramFlow vector loader.
///
/// Faithfully reproduces the 3.2s CSS keyframe sequence defined in
/// `assets/brand/GramFlow-Loader.svg`:
/// - 0% - 45%: outer squircle stroke draws in
/// - 10% - 50%: inner glyph stroke draws in
/// - 52% - 68%: evenodd fill fades in to 100%
/// - 68% - 85%: held solid
/// - 85% - 100%: strokes and fill erase / fade out
class GramFlowLoaderPainter extends CustomPainter {
  /// Normalized animation progress in range [0.0, 1.0].
  final double progress;

  /// Main color used for strokes and fill.
  final Color color;

  /// Stroke width in 500x500 design coordinates. Defaults to 7.0 (matching SVG).
  final double strokeWidth;

  /// Opacity multiplier for the fill.
  final double fillOpacityMultiplier;

  /// Opacity multiplier for strokes.
  final double strokeOpacityMultiplier;

  const GramFlowLoaderPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 7.0,
    this.fillOpacityMultiplier = 1.0,
    this.strokeOpacityMultiplier = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 500.0;
    if (scale <= 0) return;

    canvas.save();
    // Center inside available size
    canvas.translate(
      (size.width - 500.0 * scale) / 2.0,
      (size.height - 500.0 * scale) / 2.0,
    );
    canvas.scale(scale, scale);

    final t = progress.clamp(0.0, 1.0);

    // 1. Calculate outer stroke range
    double outerStart = 0.0;
    double outerEnd = 0.0;
    if (t < 0.45) {
      final p = Curves.easeInOut.transform((t / 0.45).clamp(0.0, 1.0));
      outerEnd = p * GramFlowPathData.outerLength;
    } else if (t < 0.85) {
      outerEnd = GramFlowPathData.outerLength;
    } else {
      final p = Curves.easeInOut.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0));
      outerStart = p * GramFlowPathData.outerLength;
      outerEnd = GramFlowPathData.outerLength;
    }

    // 2. Calculate inner stroke range
    double innerStart = 0.0;
    double innerEnd = 0.0;
    if (t < 0.10) {
      innerStart = 0.0;
      innerEnd = 0.0;
    } else if (t < 0.50) {
      final p = Curves.easeInOut.transform(((t - 0.10) / 0.40).clamp(0.0, 1.0));
      innerEnd = p * GramFlowPathData.innerLength;
    } else if (t < 0.85) {
      innerEnd = GramFlowPathData.innerLength;
    } else {
      final p = Curves.easeInOut.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0));
      innerStart = p * GramFlowPathData.innerLength;
      innerEnd = GramFlowPathData.innerLength;
    }

    // 3. Calculate fill opacity
    double fillOpacity = 0.0;
    if (t < 0.52) {
      fillOpacity = 0.0;
    } else if (t < 0.68) {
      final p = Curves.easeInOut.transform(((t - 0.52) / 0.16).clamp(0.0, 1.0));
      fillOpacity = p;
    } else if (t < 0.85) {
      fillOpacity = 1.0;
    } else {
      final p = Curves.easeInOut.transform(((t - 0.85) / 0.15).clamp(0.0, 1.0));
      fillOpacity = 1.0 - p;
    }

    // 4. Draw fill if visible
    final effectiveFillOpacity = (fillOpacity * fillOpacityMultiplier).clamp(
      0.0,
      1.0,
    );
    if (effectiveFillOpacity > 0.001) {
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: effectiveFillOpacity * (color.a));
      canvas.drawPath(GramFlowPathData.fillPath, fillPaint);
    }

    // 5. Draw strokes
    final effectiveStrokeOpacity =
        strokeOpacityMultiplier.clamp(0.0, 1.0) * (color.a);
    if (effectiveStrokeOpacity > 0.001) {
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: effectiveStrokeOpacity);

      if (outerEnd > outerStart + 0.5) {
        final path = GramFlowPathData.outerMetric.extractPath(
          outerStart,
          outerEnd,
        );
        canvas.drawPath(path, strokePaint);
      }

      if (innerEnd > innerStart + 0.5) {
        final path = GramFlowPathData.innerMetric.extractPath(
          innerStart,
          innerEnd,
        );
        canvas.drawPath(path, strokePaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GramFlowLoaderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.fillOpacityMultiplier != fillOpacityMultiplier ||
        oldDelegate.strokeOpacityMultiplier != strokeOpacityMultiplier;
  }
}

/// The animated GramFlow vector loader widget.
///
/// Plays the 3.2s looping animation from `assets/brand/GramFlow-Loader.svg`
/// with hardware-accelerated vector drawing.
class GramFlowLoader extends StatefulWidget {
  /// The bounding square side for the loader.
  final double size;

  /// Stroke and fill color. Defaults to [ColorScheme.onSurface] or [Colors.white].
  final Color? color;

  /// Optional external animation controller for synchronized transitions.
  final AnimationController? controller;

  const GramFlowLoader({
    super.key,
    this.size = 96,
    this.color,
    this.controller,
  });

  /// Duration of one complete animation loop (matching CSS 3.2s).
  static const Duration loopDuration = Duration(milliseconds: 3200);

  /// Normalized time at which the mark strokes and fill are completely formed (68%).
  static const double formedProgress = 0.68;

  @override
  State<GramFlowLoader> createState() => _GramFlowLoaderState();
}

class _GramFlowLoaderState extends State<GramFlowLoader>
    with SingleTickerProviderStateMixin {
  AnimationController? _internalController;

  AnimationController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = AnimationController(
        vsync: this,
        duration: GramFlowLoader.loopDuration,
      )..repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GramFlowLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      } else {
        _internalController ??= AnimationController(
          vsync: this,
          duration: GramFlowLoader.loopDuration,
        )..repeat();
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        widget.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Theme.of(context).colorScheme.onSurface);

    return Semantics(
      label: AppStrings.appName,
      image: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _effectiveController,
          builder: (context, _) {
            return CustomPaint(
              size: Size(widget.size, widget.size),
              painter: GramFlowLoaderPainter(
                progress: _effectiveController.value,
                color: effectiveColor,
              ),
            );
          },
        ),
      ),
    );
  }
}
