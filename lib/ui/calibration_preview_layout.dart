import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Shared layout for calibration camera preview boxes (keeper + shooting).
class CalibrationPreviewLayout {
  CalibrationPreviewLayout._();

  /// Fraction of screen width used for the preview box.
  static const double widthFraction = 0.96;

  /// Max fraction of screen height the preview may occupy.
  static const double maxHeightFraction = 0.68;

  /// Extra vertical scale applied after aspect-ratio sizing.
  static const double heightScale = 1.0;

  /// Vertical bias (pixels). Negative nudges the box down so the top
  /// instruction banner has room above it.
  static const double verticalBias = -28;

  /// Raw [CameraController.value.previewSize] is usually landscape; swap for UI.
  static Size orientedPreviewSize(Size previewSize) {
    if (previewSize.width > previewSize.height) {
      return Size(previewSize.height, previewSize.width);
    }
    return previewSize;
  }

  /// Cover-fit camera feed for portrait UI.
  ///
  /// [CameraController.value.previewSize] is reported in sensor (landscape)
  /// coordinates on most phones. Feeding those dimensions directly into a
  /// portrait layout makes [FittedBox] scale with the wrong aspect ratio,
  /// which looks zoomed-in and stretched. We size the child using
  /// [orientedPreviewSize] so the preview matches what the user sees.
  ///
  /// [mirror] horizontally flips the feed. The `camera` plugin mirrors the
  /// front preview on Android but not on iOS, so callers pass true on iOS with
  /// the front camera to get the same selfie-style view on both platforms
  /// (which also matches the mirrored landmark coordinates used for overlays).
  static Widget coverFitPreview(
    CameraController controller, {
    bool mirror = false,
  }) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.shrink();
    }
    final oriented = orientedPreviewSize(previewSize);
    Widget preview = ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.center,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: oriented.width,
          height: oriented.height,
          child: CameraPreview(controller),
        ),
      ),
    );
    if (mirror) {
      preview = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: preview,
      );
    }
    return preview;
  }

  /// Computes the on-screen rect for a portrait front-camera preview.
  static Rect calibrationRect(Size screen, Size portraitSize) {
    final aspect = portraitSize.height / portraitSize.width;

    var w = screen.width * widthFraction;
    var h = w * aspect * heightScale;

    final maxH = screen.height * maxHeightFraction;
    if (h > maxH) {
      h = maxH;
      w = h / (aspect * heightScale);
    }

    final left = (screen.width - w) / 2;
    final top = (screen.height - h) / 2 - verticalBias;
    return Rect.fromLTWH(left, top.clamp(8.0, screen.height - h - 8), w, h);
  }
}
