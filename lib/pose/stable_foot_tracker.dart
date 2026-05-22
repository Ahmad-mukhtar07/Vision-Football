import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../ui/pose_coordinate_mapper.dart';
import 'kick_detection_config.dart';
import 'pose_detector_service.dart';

/// Tracks one ankle with confidence, geometry checks, smoothing, and jump rejection.
class StableFootTracker {
  StableFootTracker({
    this.minConfidence = KickDetectionConfig.minAnkleConfidence,
    this.maxJumpPerFrame = KickDetectionConfig.maxAnkleJumpPerFrame,
    this.smoothingAlpha = 0.38,
  });

  final double minConfidence;
  final double maxJumpPerFrame;
  final double smoothingAlpha;

  bool? _lockedToLeft;
  Offset? _smoothedPosition;
  Offset? _heldPosition;
  int _rejectedJumps = 0;

  void lockToFoot(bool isLeft) {
    _lockedToLeft = isLeft;
    reset();
  }

  void reset() {
    _smoothedPosition = null;
    _heldPosition = null;
    _rejectedJumps = 0;
  }

  bool get isLocked => _lockedToLeft != null;

  ({Offset position, double confidence})? sampleRaw(
    List<PoseLandmark> landmarks,
    Size imageSize, {
    bool requireOnGround = true,
  }) {
    final locked = _lockedToLeft;
    if (locked == null) return null;

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = locked
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    final knee = locked
        ? byType[PoseLandmarkType.leftKnee]
        : byType[PoseLandmarkType.rightKnee];

    if (ankle == null || ankle.likelihood < minConfidence) return null;
    if (requireOnGround && !_isAnkleBelowKnee(ankle, knee, imageSize)) {
      return null;
    }

    return (
      position: _norm(ankle, imageSize),
      confidence: ankle.likelihood,
    );
  }

  ({Offset position, double confidence})? sample(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    final locked = _lockedToLeft;
    if (locked == null) return null;

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = locked
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    final knee = locked
        ? byType[PoseLandmarkType.leftKnee]
        : byType[PoseLandmarkType.rightKnee];

    if (ankle == null || ankle.likelihood < minConfidence) {
      return _heldSample();
    }

    if (!_isAnkleBelowKnee(ankle, knee, imageSize)) {
      return _heldSample();
    }

    final raw = _norm(ankle, imageSize);

    final reference = _smoothedPosition ?? _heldPosition;
    if (reference != null && (raw - reference).distance > maxJumpPerFrame) {
      _rejectedJumps++;
      return _heldSample();
    }

    _smoothedPosition = reference == null
        ? raw
        : Offset(
            reference.dx + (raw.dx - reference.dx) * smoothingAlpha,
            reference.dy + (raw.dy - reference.dy) * smoothingAlpha,
          );
    _heldPosition = _smoothedPosition;
    _rejectedJumps = 0;

    return (position: _smoothedPosition!, confidence: ankle.likelihood);
  }

  ({Offset position, double confidence})? _heldSample() {
    if (_heldPosition == null) return null;
    return (position: _heldPosition!, confidence: minConfidence);
  }

  Offset _norm(PoseLandmark landmark, Size imageSize) {
    return PoseCoordinateMapper.landmarkToNormalized(
      landmark: landmark,
      imageSize: imageSize,
      isFrontCamera: PoseDetectorService.instance.isFrontCamera,
    );
  }

  bool _isAnkleBelowKnee(
    PoseLandmark ankle,
    PoseLandmark? knee,
    Size imageSize,
  ) {
    if (knee == null || knee.likelihood < minConfidence * 0.9) {
      return true;
    }
    final ankleY = _norm(ankle, imageSize).dy;
    final kneeY = _norm(knee, imageSize).dy;
    return ankleY > kneeY + KickDetectionConfig.minAnkleBelowKneeFraction;
  }
}
