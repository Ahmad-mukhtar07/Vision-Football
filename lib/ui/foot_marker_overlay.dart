import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../game/game_foot_marker_controller.dart';
import '../game/painters/boot_marker_painter.dart';
import '../models/kicking_foot.dart';
import '../pose/kick_detector.dart';
import '../pose/pose_detector_service.dart';
import 'pose_coordinate_mapper.dart';

/// Boot marker drawn above the Flame game layer.
class FootMarkerOverlay extends StatefulWidget {
  const FootMarkerOverlay({
    super.key,
    required this.cameras,
    required this.kickingFoot,
    required this.kickDetector,
    this.gameFootMarker,
    this.gameAligned = false,
    this.showFootLabel = false,
  });

  final List<CameraDescription> cameras;
  final KickingFoot? kickingFoot;
  final KickDetector kickDetector;
  final GameFootMarkerController? gameFootMarker;
  final bool gameAligned;
  final bool showFootLabel;

  @override
  State<FootMarkerOverlay> createState() => _FootMarkerOverlayState();
}

class _FootMarkerOverlayState extends State<FootMarkerOverlay>
    with SingleTickerProviderStateMixin {
  static const double _overlayMinLikelihood = 0.55;
  static const double _stillSpeed = 0.012;
  static const double _stillSmoothAlpha = 0.55;
  static const double _fastFollowAlpha = 0.92;

  Offset? _displayNorm;
  int _holdFrames = 0;
  static const int _maxHoldFrames = 12;

  StreamSubscription<List<PoseLandmark>>? _subscription;
  StreamSubscription? _kickSubscription;

  late final AnimationController _starController;
  Offset _starOrigin = Offset.zero;

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    if (!widget.gameAligned) {
      _subscription = PoseDetectorService.instance.poseLandmarks.listen(
        _onLandmarks,
      );
    }
    _kickSubscription = widget.kickDetector.kickStream.listen((_) {
      if (!mounted) return;
      _starController.forward(from: 0);
    });
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
    _starController.dispose();
    super.dispose();
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
    final clamped = Offset(
      pt.dx.clamp(24.0, screen.width - 24),
      pt.dy.clamp(24.0, screen.height - 24),
    );
    _starOrigin = const Offset(24, 24);

    final ballCenter = marker.ballCenterScreen;
    final ringColor = switch (marker.state) {
      MarkerPositionState.tracking => marker.didPassBall
          ? Colors.greenAccent.withValues(alpha: 0.95)
          : Colors.cyanAccent.withValues(alpha: 0.75),
      MarkerPositionState.recovering => Colors.white.withValues(alpha: 0.25),
      MarkerPositionState.anchored => marker.didPassBall
          ? Colors.greenAccent.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.35),
    };

    return Stack(
      fit: StackFit.expand,
      children: [
        if (ballCenter != null)
          Positioned(
            left: ballCenter.dx - GameFootMarkerController.ballHitRadiusPx,
            top: ballCenter.dy - GameFootMarkerController.ballHitRadiusPx,
            child: IgnorePointer(
              child: Container(
                width: GameFootMarkerController.ballHitRadiusPx * 2,
                height: GameFootMarkerController.ballHitRadiusPx * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: ringColor,
                    width: marker.isTrackingStrike ? 2.5 : 2,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: clamped.dx - 24,
          top: clamped.dy - 24,
          child: AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(48, 48),
                painter: BootMarkerPainter(
                  kickFlashActive: _starController.isAnimating,
                  starBurstProgress: _starController.value,
                  starBurstOrigin: _starOrigin,
                ),
              );
            },
          ),
        ),
        if (widget.showFootLabel)
          Positioned(
            left: clamped.dx - 48,
            top: clamped.dy + 28,
            child: Text(
              marker.isTrackingStrike ? 'Strike!' : 'Kick through the ball',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(blurRadius: 4, color: Colors.black)],
              ),
            ),
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

    final sensor = PoseDetectorService.instance.cameraSensorOrientation ?? 270;
    final mapper = PoseCoordinateMapper(
      imageSize: imageSize,
      screenSize: screen,
      isFrontCamera: _isFrontCamera(),
      sensorRotation: sensor,
    );
    final pt = mapper.normalizedOffsetToScreen(norm);
    final clamped = Offset(
      pt.dx.clamp(24.0, screen.width - 24),
      pt.dy.clamp(24.0, screen.height - 24),
    );
    _starOrigin = const Offset(24, 24);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: clamped.dx - 24,
          top: clamped.dy - 24,
          child: AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(48, 48),
                painter: BootMarkerPainter(
                  kickFlashActive: _starController.isAnimating,
                  starBurstProgress: _starController.value,
                  starBurstOrigin: _starOrigin,
                ),
              );
            },
          ),
        ),
        if (widget.showFootLabel)
          Positioned(
            left: clamped.dx - 56,
            top: clamped.dy + 28,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Remember this spot — ${foot.bodyLabel}',
                style: const TextStyle(
                  color: Colors.amberAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
