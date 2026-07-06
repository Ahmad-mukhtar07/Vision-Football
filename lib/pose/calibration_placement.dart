import 'dart:ui';

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kicking_foot.dart';
import '../ui/pose_coordinate_mapper.dart';

/// A framing problem detected while the player sets up for shooting.
///
/// These are the real-world failure causes reported by testers: the foot
/// leaves the camera view mid-kick because the player stood too close, left
/// no room in front of the foot, or drifted to the edge of the frame.
enum CalibrationPlacementIssue {
  /// Framing is good — safe to calibrate and kick.
  none,

  /// The kicking foot can't be seen at all.
  footNotVisible,

  /// The leg is cut off / the player is too close to the camera.
  tooClose,

  /// The foot sits too high in the frame; a forward swing will leave view.
  noSpaceAhead,

  /// The foot is jammed against the left/right edge of the frame.
  offToSide,
}

/// Pure geometry check for calibration framing.
///
/// All thresholds are intentionally lenient so a normal, sensible setup
/// reports [CalibrationPlacementIssue.none]; only clearly problematic framing
/// is flagged.
class CalibrationPlacement {
  const CalibrationPlacement._();

  /// Ankle confidence below which we treat the foot as not visible.
  static const double _minAnkleConfidence = 0.5;

  /// Knee confidence below which we assume the leg is cut off (too close).
  static const double _minKneeConfidence = 0.5;

  /// Horizontal safe band — outside this the foot is against a side edge.
  static const double _minX = 0.12;
  static const double _maxX = 0.88;

  /// Above this (smaller y = higher in frame) there's no room to swing forward.
  static const double _minY = 0.22;

  /// Below this the foot is jammed at the bottom edge / player is too close.
  static const double _maxY = 0.93;

  static CalibrationPlacementIssue evaluate({
    required List<PoseLandmark> landmarks,
    required Size imageSize,
    required KickingFoot foot,
    required bool isFrontCamera,
  }) {
    if (landmarks.isEmpty) return CalibrationPlacementIssue.footNotVisible;

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = foot.isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    final knee = foot.isLeft
        ? byType[PoseLandmarkType.leftKnee]
        : byType[PoseLandmarkType.rightKnee];

    if (ankle == null || ankle.likelihood < _minAnkleConfidence) {
      return CalibrationPlacementIssue.footNotVisible;
    }

    // A missing/low-confidence knee means the leg is cut off — the player is
    // usually standing too close, so the foot vanishes as soon as it swings.
    if (knee == null || knee.likelihood < _minKneeConfidence) {
      return CalibrationPlacementIssue.tooClose;
    }

    final norm = PoseCoordinateMapper.landmarkToNormalized(
      landmark: ankle,
      imageSize: imageSize,
      isFrontCamera: isFrontCamera,
    );

    if (norm.dy > _maxY) return CalibrationPlacementIssue.tooClose;
    if (norm.dy < _minY) return CalibrationPlacementIssue.noSpaceAhead;
    if (norm.dx < _minX || norm.dx > _maxX) {
      return CalibrationPlacementIssue.offToSide;
    }

    return CalibrationPlacementIssue.none;
  }

  /// Short all-caps heading shown above the instruction.
  static String heading(CalibrationPlacementIssue issue) {
    switch (issue) {
      case CalibrationPlacementIssue.none:
        return '';
      case CalibrationPlacementIssue.footNotVisible:
        return 'FOOT NOT VISIBLE';
      case CalibrationPlacementIssue.tooClose:
        return 'TOO CLOSE';
      case CalibrationPlacementIssue.noSpaceAhead:
        return 'NO SPACE AHEAD';
      case CalibrationPlacementIssue.offToSide:
        return 'MOVE TO CENTRE';
    }
  }

  /// Actionable one-line instruction for the player.
  static String instruction(
    CalibrationPlacementIssue issue,
    KickingFoot foot,
  ) {
    final footLabel = foot.bodyLabel.toLowerCase();
    switch (issue) {
      case CalibrationPlacementIssue.none:
        return '';
      case CalibrationPlacementIssue.footNotVisible:
        return 'Step into frame so your $footLabel foot is visible';
      case CalibrationPlacementIssue.tooClose:
        return 'Step back so your whole leg stays in view';
      case CalibrationPlacementIssue.noSpaceAhead:
        return 'Leave space in front of your foot — step back or lower your phone';
      case CalibrationPlacementIssue.offToSide:
        return 'Move to the centre of the frame';
    }
  }
}
