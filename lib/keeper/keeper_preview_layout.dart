import 'dart:ui';

/// Shared layout for the keeper calibration camera preview box.
///
/// Both [KeeperCameraPreview] and [GloveOverlay] use this so glove markers
/// line up with the video during calibration.
class KeeperPreviewLayout {
  KeeperPreviewLayout._();

  /// Fraction of screen width used for the preview box.
  static const double widthFraction = 0.96;

  /// Max fraction of screen height the preview may occupy.
  static const double maxHeightFraction = 0.68;

  /// Extra vertical scale applied after aspect-ratio sizing.
  static const double heightScale = 1.08;

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

  /// Computes the on-screen rect for a portrait front-camera preview.
  ///
  /// [portraitSize] should be the display-oriented size (height > width).
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
