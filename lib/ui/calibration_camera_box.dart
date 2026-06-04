import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'calibration_preview_layout.dart';
import 'outline_image_overlay.dart';

/// Portrait calibration camera preview with an optional body-outline overlay.
class CalibrationCameraBox extends StatelessWidget {
  const CalibrationCameraBox({
    super.key,
    required this.controller,
    required this.outlineAsset,
  });

  final CameraController controller;
  final String outlineAsset;

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
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Box aspect matches portrait preview; cover with raw
                        // sensor dimensions so the feed is never squashed.
                        FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: previewSize.width,
                            height: previewSize.height,
                            child: CameraPreview(controller),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: OutlineImageOverlay(
                              assetPath: outlineAsset,
                            ),
                          ),
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
}
