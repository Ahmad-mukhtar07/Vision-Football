import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kicking_foot.dart';
import '../pose/kick_detector.dart';
import '../pose/pose_detector_service.dart';
import 'pose_coordinate_mapper.dart';

/// Foot dot drawn **above** the Flame game layer (camera overlay is hidden under pitch).
class FootMarkerOverlay extends StatefulWidget {
  const FootMarkerOverlay({
    super.key,
    required this.cameras,
    required this.kickingFoot,
    required this.kickDetector,
  });

  final List<CameraDescription> cameras;
  final KickingFoot? kickingFoot;
  final KickDetector kickDetector;

  @override
  State<FootMarkerOverlay> createState() => _FootMarkerOverlayState();
}

class _FootMarkerOverlayState extends State<FootMarkerOverlay> {
  static const double _overlayMinLikelihood = 0.55;
  /// Light smooth only when nearly still — fast kicks use raw ML Kit position.
  static const double _stillSpeed = 0.012;
  static const double _stillSmoothAlpha = 0.55;
  static const double _fastFollowAlpha = 0.92;

  Offset? _displayNorm;
  int _holdFrames = 0;
  static const int _maxHoldFrames = 12;

  StreamSubscription<List<PoseLandmark>>? _subscription;
  StreamSubscription? _kickSubscription;
  bool _kickFlashActive = false;

  @override
  void initState() {
    super.initState();
    _subscription = PoseDetectorService.instance.poseLandmarks.listen(
      _onLandmarks,
    );
    _kickSubscription = widget.kickDetector.kickStream.listen((_) {
      if (!mounted) return;
      setState(() => _kickFlashActive = true);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _kickFlashActive = false);
      });
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
        final fill =
            _kickFlashActive ? Colors.greenAccent : Colors.orangeAccent;

        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: pt.dx - 22,
              top: pt.dy - 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 8,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
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
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
