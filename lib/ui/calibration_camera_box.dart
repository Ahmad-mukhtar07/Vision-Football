import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'calibration_preview_layout.dart';
import 'corner_frame_overlay.dart';
import 'outline_image_overlay.dart';

/// Visual guide drawn over the calibration camera feed.
enum CalibrationGuideStyle {
  /// Golden PNG body outline (shooting mode).
  outline,

  /// Minimal white corner brackets (keeper mode).
  cornerFrame,

  none,
}

/// Portrait calibration camera preview with an optional body-outline overlay.
class CalibrationCameraBox extends StatelessWidget {
  const CalibrationCameraBox({
    super.key,
    required this.controller,
    this.guideStyle = CalibrationGuideStyle.outline,
    this.outlineAsset,
  });

  final CameraController controller;
  final CalibrationGuideStyle guideStyle;

  /// Required when [guideStyle] is [CalibrationGuideStyle.outline].
  final String? outlineAsset;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final portraitSize =
            CalibrationPreviewLayout.orientedPreviewSize(previewSize);
        final rect = CalibrationPreviewLayout.calibrationRect(
          screen,
          portraitSize,
        );

        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CalibrationPreviewLayout.coverFitPreview(controller),
                        if (guideStyle != CalibrationGuideStyle.none)
                          Positioned.fill(
                            child: IgnorePointer(child: _guideOverlay()),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _guideOverlay() {
    return switch (guideStyle) {
      CalibrationGuideStyle.outline => OutlineImageOverlay(
          assetPath: outlineAsset!,
        ),
      CalibrationGuideStyle.cornerFrame => const CornerFrameOverlay(),
      CalibrationGuideStyle.none => const SizedBox.shrink(),
    };
  }
}
