import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../game/game_foot_marker_controller.dart';
import '../models/kicking_foot.dart';
import '../pose/kick_detector.dart';
import '../pose/pose_detector_service.dart';
import 'pose_coordinate_mapper.dart';
import 'widgets/boot_marker_widget.dart';

/// Football boot marker drawn above the Flame game layer.
class FootMarkerOverlay extends StatefulWidget {
  const FootMarkerOverlay({
    super.key,
    required this.cameras,
    required this.kickingFoot,
    required this.kickDetector,
    this.gameFootMarker,
    this.gameAligned = false,
    this.setupFullscreen = false,
  });

  final List<CameraDescription> cameras;
  final KickingFoot? kickingFoot;
  final KickDetector kickDetector;
  final GameFootMarkerController? gameFootMarker;
  final bool gameAligned;

  /// Full-screen setup camera — use mirrored screen coords for the boot marker.
  final bool setupFullscreen;

  @override
  State<FootMarkerOverlay> createState() => _FootMarkerOverlayState();
}

class _FootMarkerOverlayState extends State<FootMarkerOverlay>
    with TickerProviderStateMixin {
  static const double _overlayMinLikelihood = 0.55;
  static const double _stillSpeed = 0.012;
  static const double _stillSmoothAlpha = 0.55;
  static const double _fastFollowAlpha = 0.92;

  static const double _bootW = BootMarkerLayout.width;
  static const double _bootH = BootMarkerLayout.height;
  static final Offset _bootAnchor = BootMarkerLayout.anchor;

  static const double _strikeLineHeight = 6;

  Offset? _displayNorm;
  int _holdFrames = 0;
  static const int _maxHoldFrames = 12;

  StreamSubscription<List<PoseLandmark>>? _subscription;
  StreamSubscription? _kickSubscription;

  late final AnimationController _kickFlashController;
  bool _kickFlashActive = false;

  /// Repaints the swing trail while it fades out, independent of pose frames.
  Ticker? _trailTicker;

  @override
  void initState() {
    super.initState();
    _kickFlashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _kickFlashActive = false);
        }
      });
    if (!widget.gameAligned) {
      _subscription = PoseDetectorService.instance.poseLandmarks.listen(
        _onLandmarks,
      );
    }
    widget.gameFootMarker?.addListener(_onMarkerChanged);
    _kickSubscription = widget.kickDetector.kickStream.listen((_) {
      if (!mounted) return;
      setState(() => _kickFlashActive = true);
      _kickFlashController.forward(from: 0);
    });
  }

  void _onMarkerChanged() {
    // Kick off the fade-out ticker as soon as a swing trail appears.
    if (widget.gameFootMarker?.hasActiveTrail ?? false) {
      _ensureTrailTicker();
    }
  }

  void _ensureTrailTicker() {
    if (_trailTicker != null) return;
    _trailTicker = createTicker((_) {
      final marker = widget.gameFootMarker;
      if (!mounted || marker == null || !marker.hasActiveTrail) {
        _stopTrailTicker();
        if (mounted) setState(() {});
        return;
      }
      setState(() {});
    })
      ..start();
  }

  void _stopTrailTicker() {
    _trailTicker?.dispose();
    _trailTicker = null;
  }

  void _onLandmarks(List<PoseLandmark> landmarks) {
    final foot = widget.kickingFoot;
    final imageSize = PoseDetectorService.instance.lastImageSize;
    if (foot == null || imageSize == null) {
      if (_displayNorm != null && _holdFrames < _maxHoldFrames) {
        _holdFrames++;
        setState(() {});
      }
      return;
    }

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = foot.isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];

    if (ankle == null || ankle.likelihood < _overlayMinLikelihood) {
      if (_displayNorm != null && _holdFrames < _maxHoldFrames) {
        _holdFrames++;
        setState(() {});
      }
      return;
    }

    _holdFrames = 0;
    final raw = PoseCoordinateMapper.landmarkToNormalized(
      landmark: ankle,
      imageSize: imageSize,
      isFrontCamera: _isFrontCamera(),
    );
    final ref = _displayNorm;
    if (ref == null) {
      _displayNorm = raw;
    } else {
      final speed = (raw - ref).distance;
      final alpha = speed > _stillSpeed ? _fastFollowAlpha : _stillSmoothAlpha;
      _displayNorm = Offset(
        ref.dx + (raw.dx - ref.dx) * alpha,
        ref.dy + (raw.dy - ref.dy) * alpha,
      );
    }
    setState(() {});
  }

  bool _isFrontCamera() {
    final frontIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    final camera = widget.cameras[frontIndex >= 0 ? frontIndex : 0];
    return camera.lensDirection == CameraLensDirection.front;
  }

  @override
  void didUpdateWidget(covariant FootMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gameFootMarker != widget.gameFootMarker) {
      oldWidget.gameFootMarker?.removeListener(_onMarkerChanged);
      widget.gameFootMarker?.addListener(_onMarkerChanged);
    }
    if (oldWidget.kickingFoot != widget.kickingFoot) {
      _displayNorm = null;
      _holdFrames = 0;
    }
    if (oldWidget.gameAligned != widget.gameAligned) {
      if (widget.gameAligned) {
        _subscription?.cancel();
        _subscription = null;
      } else {
        _subscription ??= PoseDetectorService.instance.poseLandmarks.listen(
          _onLandmarks,
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _kickSubscription?.cancel();
    widget.gameFootMarker?.removeListener(_onMarkerChanged);
    _stopTrailTicker();
    _kickFlashController.dispose();
    super.dispose();
  }

  Offset _bootTopLeft(Offset footPoint) => footPoint - _bootAnchor;

  Offset _clampFootPoint(Offset pt, Size screen) => Offset(
        pt.dx.clamp(_bootAnchor.dx, screen.width - (_bootW - _bootAnchor.dx)),
        pt.dy.clamp(_bootAnchor.dy, screen.height - (_bootH - _bootAnchor.dy)),
      );

  Widget _bootMarkerWidget(KickingFoot foot) {
    return BootMarkerWidget(
      isLeftFoot: foot.isLeft,
      kickFlashActive: _kickFlashActive,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foot = widget.kickingFoot;
    if (foot == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        widget.gameFootMarker?.configureForScreen(screen);

        if (widget.gameAligned) {
          return _buildGameAligned(screen, foot);
        }
        return _buildCalibrationAligned(screen, foot);
      },
    );
  }

  Widget _buildGameAligned(Size screen, KickingFoot foot) {
    final marker = widget.gameFootMarker;
    if (marker == null) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: marker,
      builder: (context, _) {
        final pt = marker.screenPosition;
        if (pt == null) return const SizedBox.shrink();
        return _gameAlignedStack(screen, foot, marker, pt);
      },
    );
  }

  Widget _gameAlignedStack(
    Size screen,
    KickingFoot foot,
    GameFootMarkerController marker,
    Offset pt,
  ) {
    final clamped = _clampFootPoint(pt, screen);
    final ballCenter = marker.ballCenterScreen;
    final passed = marker.isEligibleForStrike || marker.didPassBall;
    final lineColor = passed
        ? Colors.greenAccent.withValues(alpha: 0.95)
        : (marker.isTrackingStrike
            ? Colors.cyanAccent.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.5));

    final bootPos = _bootTopLeft(clamped);
    final bandHalfWidth = marker.strikeBandHalfWidth;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _SwipeTrailPainter(
                points: marker.trail,
                trailDuration: GameFootMarkerController.trailDuration,
              ),
            ),
          ),
        ),
        if (ballCenter != null)
          Positioned(
            left: ballCenter.dx - bandHalfWidth,
            top: ballCenter.dy - _strikeLineHeight / 2,
            child: IgnorePointer(
              child: _StrikeLine(
                width: bandHalfWidth * 2,
                height: _strikeLineHeight,
                color: lineColor,
              ),
            ),
          ),
        Positioned(
          left: bootPos.dx,
          top: bootPos.dy,
          child: _bootMarkerWidget(foot),
        ),
      ],
    );
  }

  Widget _buildCalibrationAligned(Size screen, KickingFoot foot) {
    final norm = _displayNorm;
    final imageSize = PoseDetectorService.instance.lastImageSize;
    if (norm == null || imageSize == null) {
      return const SizedBox.shrink();
    }

    final Offset pt;
    if (widget.setupFullscreen) {
      final sensor =
          PoseDetectorService.instance.cameraSensorOrientation ?? 270;
      final mapper = PoseCoordinateMapper(
        imageSize: imageSize,
        screenSize: screen,
        isFrontCamera: _isFrontCamera(),
        sensorRotation: sensor,
      );
      pt = mapper.normalizedOffsetToScreen(norm);
    } else {
      // Legacy boxed preview path (unused in current shooting flow).
      pt = Offset(norm.dx * screen.width, norm.dy * screen.height);
    }

    final clamped = _clampFootPoint(pt, screen);
    final bootPos = _bootTopLeft(clamped);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: bootPos.dx,
          top: bootPos.dy,
          child: _bootMarkerWidget(foot),
        ),
      ],
    );
  }
}

/// Subtle horizontal "strike line" drawn through the ball. Reads as a kick
/// guide: brightest at the center (over the ball) and fading to transparent at
/// the edges, with a soft glow. The ball itself stays a normal circle.
class _StrikeLine extends StatelessWidget {
  const _StrikeLine({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color,
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.4, 0.6, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }
}

/// Fruit Ninja-style fading streak following the foot marker through a swing.
///
/// Each segment's opacity and width are scaled by the age of its points so the
/// trail fades over [trailDuration]; newer (leading) segments are brighter and
/// thicker, older (tail) segments thinner and more transparent.
class _SwipeTrailPainter extends CustomPainter {
  _SwipeTrailPainter({
    required this.points,
    required this.trailDuration,
  });

  final List<FootTrailPoint> points;
  final Duration trailDuration;

  static const double _maxStrokeWidth = 14;
  static const double _minStrokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final now = DateTime.now();
    final totalMs = trailDuration.inMilliseconds;

    for (int i = 1; i < points.length; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];

      // recency: 0 (oldest still-visible) → 1 (newest). Drop expired points.
      final ageMs = now.difference(p1.time).inMilliseconds;
      if (ageMs >= totalMs) continue;
      final recency = (1.0 - ageMs / totalMs).clamp(0.0, 1.0);

      final width = _minStrokeWidth +
          (_maxStrokeWidth - _minStrokeWidth) * recency;

      // Outer soft glow.
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width * 1.9
        ..color = Colors.cyanAccent.withValues(alpha: 0.18 * recency)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawLine(p0.position, p1.position, glowPaint);

      // Bright core.
      final corePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = Colors.white.withValues(alpha: 0.85 * recency);
      canvas.drawLine(p0.position, p1.position, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SwipeTrailPainter oldDelegate) => true;
}
