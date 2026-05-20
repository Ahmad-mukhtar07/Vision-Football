import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Maps ML Kit pose landmarks from image space to screen/preview coordinates.
class PoseCoordinateMapper {
  const PoseCoordinateMapper({
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  /// Maps a landmark to screen pixels, accounting for preview scale and rotation.
  Offset normalizedToScreen(PoseLandmark landmark, Size screenSize) {
    return Offset(
      _translateX(landmark.x, screenSize),
      _translateY(landmark.y, screenSize),
    );
  }

  /// Maps normalized image coords (0–1) to screen pixels (same transform as landmarks).
  Offset normalizedOffsetToScreen(Offset normalized, Size screenSize) {
    return Offset(
      _translateX(normalized.dx * imageSize.width, screenSize),
      _translateY(normalized.dy * imageSize.height, screenSize),
    );
  }

  double normalizedX(PoseLandmark landmark) => landmark.x / imageSize.width;

  double normalizedY(PoseLandmark landmark) => landmark.y / imageSize.height;

  double _translateX(double x, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x *
            canvasSize.width /
            (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return canvasSize.width -
            x *
                canvasSize.width /
                (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        switch (lensDirection) {
          case CameraLensDirection.back:
            return x * canvasSize.width / imageSize.width;
          default:
            return canvasSize.width - x * canvasSize.width / imageSize.width;
        }
    }
  }

  double _translateY(double y, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y *
            canvasSize.height /
            (Platform.isIOS ? imageSize.height : imageSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * canvasSize.height / imageSize.height;
    }
  }
}
