import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'calibration_preview_layout.dart';

/// Edge-to-edge camera feed using [BoxFit.cover] — no letterboxing.
class FullscreenCameraPreview extends StatelessWidget {
  const FullscreenCameraPreview({
    super.key,
    required this.controller,
    this.mirror = false,
  });

  final CameraController controller;

  /// Horizontally flips the feed (see [CalibrationPreviewLayout.coverFitPreview]).
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    if (controller.value.previewSize == null) {
      return const ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(),
      );
    }

    return ColoredBox(
      color: Colors.black,
      child: SizedBox.expand(
        child: CalibrationPreviewLayout.coverFitPreview(
          controller,
          mirror: mirror,
        ),
      ),
    );
  }
}
