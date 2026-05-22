import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Maps ML Kit pose landmarks to portrait screen / normalized coordinates.
class PoseCoordinateMapper {
  PoseCoordinateMapper({
    required this.imageSize,
    required this.screenSize,
    required this.isFrontCamera,
    required this.sensorRotation,
  });

  final Size imageSize;
  final Size screenSize;
  final bool isFrontCamera;
  final int sensorRotation;

  static bool _loggedLandmarkFormat = false;

  /// Normalized (0–1) image coords with front-camera mirror applied.
  Offset normalizedToNormalized(PoseLandmark landmark) {
    final norm = _landmarkToNormalized(landmark);
    if (!_loggedLandmarkFormat) {
      _loggedLandmarkFormat = true;
      final unit = landmark.x <= 2.0 && landmark.y <= 2.0 ? 'normalized' : 'pixels';
      debugPrint(
        '[MAPPER] raw landmark x=${landmark.x.toStringAsFixed(2)} '
        'y=${landmark.y.toStringAsFixed(2)} ($unit) '
        '→ norm=(${norm.dx.toStringAsFixed(2)}, ${norm.dy.toStringAsFixed(2)}) '
        'sensor=$sensorRotation front=$isFrontCamera',
      );
    }
    return norm;
  }

  /// Portrait screen pixels for overlay / foot marker.
  Offset toScreen(PoseLandmark landmark) {
    final norm = normalizedToNormalized(landmark);
    return Offset(norm.dx * screenSize.width, norm.dy * screenSize.height);
  }

  /// Maps stored normalized coords to screen (same mirror already applied).
  Offset normalizedOffsetToScreen(Offset normalized) {
    return Offset(
      normalized.dx * screenSize.width,
      normalized.dy * screenSize.height,
    );
  }

  Offset _landmarkToNormalized(PoseLandmark landmark) {
    double nx;
    double ny;
    if (landmark.x > 2.0 || landmark.y > 2.0) {
      nx = landmark.x / imageSize.width;
      ny = landmark.y / imageSize.height;
    } else {
      nx = landmark.x;
      ny = landmark.y;
    }
    if (isFrontCamera) {
      nx = 1.0 - nx;
    }
    return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
  }

  /// Shared normalization for kick detection (mirror only, no screen scale).
  static Offset landmarkToNormalized({
    required PoseLandmark landmark,
    required Size imageSize,
    required bool isFrontCamera,
  }) {
    double nx;
    double ny;
    if (landmark.x > 2.0 || landmark.y > 2.0) {
      nx = landmark.x / imageSize.width;
      ny = landmark.y / imageSize.height;
    } else {
      nx = landmark.x;
      ny = landmark.y;
    }
    if (isFrontCamera) {
      nx = 1.0 - nx;
    }
    return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
  }
}
