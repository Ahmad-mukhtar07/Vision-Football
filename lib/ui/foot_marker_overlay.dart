import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
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
    with SingleTickerProviderStateMixin {
  static const double _overlayMinLikelihood = 0.55;
  static const double _stillSpeed = 0.012;
  static const double _stillSmoothAlpha = 0.55;
  static const double _fastFollowAlpha = 0.92;

  static const double _bootW = BootMarkerLayout.width;
  static const double _bootH = BootMarkerLayout.height;
  static final Offset _bootAnchor = BootMarkerLayout.anchor;

  Offset? _displayNorm;
  int _holdFrames = 0;
  static const int _maxHoldFrames = 12;

  StreamSubscription<List<PoseLandmark>>? _subscription;
  StreamSubscription? _kickSubscription;

  late final AnimationController _kickFlashController;
  bool _kickFlashActive = false;

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
    _kickSubscription = widget.kickDetector.kickStream.listen((_) {
      if (!mounted) return;
      setState(() => _kickFlashActive = true);
      _kickFlashController.forward(from: 0);
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
    final ringColor = switch (marker.state) {
      MarkerPositionState.tracking => marker.didPassBall
          ? Colors.greenAccent.withValues(alpha: 0.95)
          : Colors.cyanAccent.withValues(alpha: 0.75),
      MarkerPositionState.recovering => Colors.white.withValues(alpha: 0.25),
      MarkerPositionState.anchored => marker.didPassBall
          ? Colors.greenAccent.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.35),
    };

    final bootPos = _bootTopLeft(clamped);

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
