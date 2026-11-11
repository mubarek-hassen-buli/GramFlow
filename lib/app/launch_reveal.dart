import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gramx/app/app_shell.dart';
import 'package:gramx/app/router.dart';
import 'package:gramx/app/splash_screen.dart';
import 'package:gramx/app/theme/brand_assets.dart';
import 'package:gramx/app/widgets/gramflow_loader.dart';
import 'package:gramx/features/feed/domain/post.dart';
import 'package:gramx/features/feed/presentation/feed_providers.dart';
import 'package:gramx/features/guest/presentation/guest_providers.dart';

/// Placement of the launch mark and the frame where the ribbon is finished.
abstract final class LaunchMark {
  /// The first frame of [BrandAssets.markAnimation] where the ribbon has
  /// finished forming, about 1.4 s in. The launch stops here.
  static const int formedFrame = 79;

  /// The finished ribbon's bounds inside the 276 × 429 animation canvas.
  static const Rect source = Rect.fromLTRB(8, 68, 268, 348);

  /// How tall the finished ribbon is on screen, centred.
  static const double height = 110;

  static double get width => height * source.width / source.height;

  /// The zoom centre, as a fraction of [source]. It sits inside the solid
  /// front panel so the zoomed ribbon covers the whole screen.
  static const Offset anchor = Offset(0.34, 0.55);

  /// The longest the drawing may take to reach [formedFrame] before the app
  /// opens without it, in case the decode never returns.
  static const Duration drawingLimit = Duration(seconds: 3);
}

/// Covers the app in black, matching the system launch screen, and plays
/// the GramFlow vector animation from [BrandAssets.loaderSvg]. Once the first
/// screen is ready the mark zooms while the black is cut away in its shape.
///
/// The home feed is ready when its first posts arrive or after [feedPatience];
/// other routes once the router leaves the splash. With reduced motion the
/// black just fades.
class LaunchReveal extends ConsumerStatefulWidget {
  final Widget child;

  const LaunchReveal({super.key, required this.child});

  /// Longest the mark waits on the feed once the router has reached it.
  static const Duration feedPatience = Duration(milliseconds: 700);

  @override
  ConsumerState<LaunchReveal> createState() => _LaunchRevealState();
}

class _LaunchRevealState extends ConsumerState<LaunchReveal>
    with TickerProviderStateMixin {
  /// One sweep of the sheen and the rest before the next.
  late final AnimationController _sheen = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  );

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  /// Drives the animated GramFlow vector loader.
  late final AnimationController _loaderController = AnimationController(
    vsync: this,
    duration: GramFlowLoader.loopDuration,
  );

  Timer? _drawingLimit;

  GoRouterDelegate? _delegate;
  Timer? _patience;
  ProviderSubscription<AsyncValue<List<Post>>>? _feed;

  bool _started = false;
  bool _formed = false;
  bool _ready = false;
  bool _revealing = false;
  bool _done = false;

  /// The platform's reduce-motion setting, as of the last build.
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _delegate = ref.read(routerProvider).routerDelegate..addListener(_check);

    _reveal.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _sheen.stop();
      _stopDrawing();
      setState(() => _done = true);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs MediaQuery, so not in initState.
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _formed = true;
    } else {
      _startDrawing();
    }
  }

  @override
  void dispose() {
    _delegate?.removeListener(_check);
    _patience?.cancel();
    _feed?.close();
    _stopDrawing();
    _loaderController.dispose();
    _sheen.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _startDrawing() {
    _drawingLimit = Timer(LaunchMark.drawingLimit, _markFormed);
    _loaderController.addListener(_checkLoaderFormed);
    _loaderController.repeat();
  }

  void _checkLoaderFormed() {
    if (_loaderController.value >= GramFlowLoader.formedProgress) {
      _loaderController.removeListener(_checkLoaderFormed);
      _markFormed();
    }
  }

  void _stopDrawing() {
    _drawingLimit?.cancel();
    _loaderController.removeListener(_checkLoaderFormed);
    _loaderController.stop();
  }

  void _markFormed() {
    if (_formed || !mounted) return;
    _formed = true;
    if (_ready) {
      _open();
    } else {
      _sheen.repeat();
    }
  }

  /// Checks whether the first screen is ready. See [LaunchReveal].
  void _check() {
    if (_ready || !mounted) return;
    final configuration = _delegate?.currentConfiguration;
    if (configuration == null || configuration.isEmpty) return;

    final path = configuration.uri.path;
    if (path == SplashScreen.route) return;

    final waitsForFeed =
        path == ShellTab.home.path && !ref.read(isGuestModeProvider);
    if (!waitsForFeed) return _markReady();

    _feed ??= ref.listenManual(feedPostsProvider, (_, next) {
      if (next.value?.isNotEmpty ?? false) _markReady();
    }, fireImmediately: true);
    _patience ??= Timer(LaunchReveal.feedPatience, _markReady);
  }

  void _markReady() {
    if (_ready || !mounted) return;
    _ready = true;
    _patience?.cancel();
    _feed?.close();
    _feed = null;
    _delegate?.removeListener(_check);
    if (_formed) _open();
  }

  /// Starts the reveal. No `setState`, since this can run from a router
  /// notification during a build.
  void _open() {
    if (_revealing || !mounted) return;
    _revealing = true;
    _sheen.stop();
    if (_reduceMotion) {
      _reveal.duration = const Duration(milliseconds: 200);
    }
    _reveal.forward();
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.of(context).disableAnimations;

    // The app stays the first child so removing the cover does not rebuild it.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            // Touches reach the app as soon as it starts to show through.
            child: AnimatedBuilder(
              animation: Listenable.merge([_reveal, _loaderController, _sheen]),
              builder: (context, child) =>
                  IgnorePointer(ignoring: _reveal.value > 0, child: child),
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _LaunchPainter(
                    loaderProgress: _loaderController,
                    sheen: _sheen,
                    reveal: _reveal,
                    reduceMotion: _reduceMotion,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LaunchPainter extends CustomPainter {
  final Animation<double> loaderProgress;
  final Animation<double> sheen;
  final Animation<double> reveal;
  final bool reduceMotion;

  _LaunchPainter({
    required this.loaderProgress,
    required this.sheen,
    required this.reveal,
    required this.reduceMotion,
  }) : super(repaint: Listenable.merge([loaderProgress, sheen, reveal]));

  /// The share of the reveal spent on the dip, before the zoom.
  static const double _dip = 0.2;

  /// How far the ribbon has shrunk at the bottom of the dip.
  static const double _dipScale = 0.92;

  /// Zoom that covers a 460 × 1000 screen; larger screens scale it up.
  static const double _zoomScale = 16;

  static final Paint _plain = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final t = reveal.value;

    if (reduceMotion) {
      canvas.drawRect(bounds, Paint()..color = _black(1 - t));
      return;
    }

    var scale = 1.0;
    var markOpacity = 1.0;
    var veilOpacity = 1.0;
    var zooming = false;

    if (t > 0) {
      if (t < _dip) {
        final dip = Curves.easeOut.transform(t / _dip);
        scale = ui.lerpDouble(1, _dipScale, dip)!;
      } else {
        zooming = true;
        final zoom = (t - _dip) / (1 - _dip);
        final reach =
            _zoomScale *
            math.max(1, math.max(size.width / 460, size.height / 1000));
        scale = ui.lerpDouble(
          _dipScale,
          reach,
          Curves.easeInCubic.transform(zoom),
        )!;
        // The mark's colour fades early, leaving only its cut-out shape.
        markOpacity = 1 - Curves.easeOut.transform((zoom / 0.35).clamp(0, 1));
        // Fade the remaining black at the end to clear the stretched soft edge.
        veilOpacity = 1 - ((zoom - 0.7) / 0.3).clamp(0.0, 1.0);
      }
    }

    final markSize = LaunchMark.height;
    final markScale = (markSize / 300.0) * scale;

    // 1. Draw black veil, with mark cut out if zooming
    canvas.saveLayer(bounds, _plain);
    canvas.drawRect(bounds, Paint()..color = _black(veilOpacity));
    if (zooming) {
      canvas.save();
      canvas.translate(bounds.center.dx, bounds.center.dy);
      canvas.scale(markScale, markScale);
      canvas.translate(
        -GramFlowPathData.center.dx,
        -GramFlowPathData.center.dy,
      );
      canvas.drawPath(
        GramFlowPathData.fillPath,
        Paint()..blendMode = BlendMode.dstOut,
      );
      canvas.restore();
    }
    canvas.restore();

    // 2. Draw the mark while visible
    if (markOpacity > 0) {
      if (t == 0) {
        // Not revealing yet: play the animated vector loader!
        final loaderSide = markSize * (500.0 / 300.0);
        canvas.save();
        canvas.translate(
          bounds.center.dx - loaderSide / 2.0,
          bounds.center.dy - loaderSide / 2.0,
        );
        final loaderPainter = GramFlowLoaderPainter(
          progress: loaderProgress.value,
          color: Colors.white,
          fillOpacityMultiplier: markOpacity,
          strokeOpacityMultiplier: markOpacity,
        );
        loaderPainter.paint(canvas, Size(loaderSide, loaderSide));
        canvas.restore();

        // Draw sheen if active
        _drawSheen(canvas, bounds.center, markSize);
      } else {
        // Zooming / dipping: draw the solid mark scaled
        canvas.save();
        canvas.translate(bounds.center.dx, bounds.center.dy);
        canvas.scale(markScale, markScale);
        canvas.translate(
          -GramFlowPathData.center.dx,
          -GramFlowPathData.center.dy,
        );
        canvas.drawPath(
          GramFlowPathData.fillPath,
          Paint()..color = Colors.white.withValues(alpha: markOpacity),
        );
        canvas.restore();
      }
    }
  }

  /// A band of light across the mark, kept to the mark's own shape.
  void _drawSheen(Canvas canvas, Offset center, double height) {
    if (sheen.value == 0) return;

    const sweep = 0.55;
    final phase = sheen.value / sweep;
    if (phase >= 1) return;
    final travel = Curves.easeInOut.transform(phase);

    final markWidth = height;
    final band = markWidth * 0.45;
    final left = center.dx - markWidth / 2.0;
    final top = center.dy - height / 2.0;
    final x = ui.lerpDouble(left - band, left + markWidth + band, travel)!;
    final shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.38),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const [0.0, 0.5, 1.0],
    ).createShader(Rect.fromLTWH(x - band, top, band * 2, height));

    final markRect = Rect.fromCenter(
      center: center,
      width: markWidth,
      height: height,
    );
    canvas.saveLayer(markRect, _plain);
    canvas.drawRect(markRect, Paint()..shader = shader);

    // Mask with GramFlow fill path
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(height / 300.0);
    canvas.translate(-GramFlowPathData.center.dx, -GramFlowPathData.center.dy);
    canvas.drawPath(
      GramFlowPathData.fillPath,
      Paint()..blendMode = BlendMode.dstIn,
    );
    canvas.restore();

    canvas.restore();
  }

  static Color _black(double opacity) => Color.fromRGBO(0, 0, 0, opacity);

  @override
  bool shouldRepaint(_LaunchPainter oldDelegate) =>
      oldDelegate.loaderProgress != loaderProgress ||
      oldDelegate.sheen != sheen ||
      oldDelegate.reveal != reveal ||
      oldDelegate.reduceMotion != reduceMotion;
}
