import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Edge-to-edge camera feed using [BoxFit.cover] — no letterboxing.
class FullscreenCameraPreview extends StatelessWidget {
  const FullscreenCameraPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.expand();
    }

    return SizedBox(
      width: MediaQuery.sizeOf(context).width,
      height: MediaQuery.sizeOf(context).height,
      child: ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: previewSize.width,
            height: previewSize.height,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}
