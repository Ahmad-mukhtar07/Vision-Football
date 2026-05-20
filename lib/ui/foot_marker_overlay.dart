import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

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
    this.showFootLabel = false,
  });

  final List<CameraDescription> cameras;
  final KickingFoot? kickingFoot;
  final KickDetector kickDetector;
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
    _subscription = PoseDetectorService.instance.poseLandmarks.listen(
      _onLandmarks,
    );
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
    final raw = Offset(
      ankle.x / imageSize.width,
      ankle.y / imageSize.height,
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

  @override
  void didUpdateWidget(covariant FootMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kickingFoot != widget.kickingFoot) {
      _displayNorm = null;
      _holdFrames = 0;
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
    final norm = _displayNorm;
    final foot = widget.kickingFoot;
    final imageSize = PoseDetectorService.instance.lastImageSize;
    final rotation = PoseDetectorService.instance.lastRotation;
    if (norm == null || foot == null || imageSize == null || rotation == null) {
      return const SizedBox.shrink();
    }

    final frontIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    final camera = widget.cameras[frontIndex >= 0 ? frontIndex : 0];

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final mapper = PoseCoordinateMapper(
          imageSize: imageSize,
          rotation: rotation,
          lensDirection: camera.lensDirection,
        );
        final pt = mapper.normalizedOffsetToScreen(norm, screen);
        _starOrigin = const Offset(24, 24);

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: pt.dx - 24,
              top: pt.dy - 24,
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
                left: pt.dx - 40,
                top: pt.dy + 28,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    foot.bodyLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
