import 'dart:ui';

/// Shared layout for the keeper calibration camera preview box.
///
/// Both [KeeperCameraPreview] and [GloveOverlay] use this so glove markers
/// line up with the video during calibration.
class KeeperPreviewLayout {
  KeeperPreviewLayout._();

  /// Fraction of screen width used for the preview box.
  static const double widthFraction = 0.88;

  /// Max fraction of screen height the preview may occupy.
  static const double maxHeightFraction = 0.60;

  /// Extra vertical scale applied after aspect-ratio sizing.
  static const double heightScale = 1.08;

  /// Vertical bias (pixels) to leave room for the HUD banner above center.
  static const double verticalBias = 48;

  /// Computes the on-screen rect for a portrait-oriented front-camera preview.
  ///
  /// [previewSize] is the raw [CameraController.value.previewSize] (typically
  /// landscape). The box preserves that aspect ratio without stretching.
  static Rect calibrationRect(Size screen, Size bufferSize) {
    // Camera buffers are usually landscape; portrait UI swaps width/height.
    final double displayW;
    final double displayH;
    if (bufferSize.width > bufferSize.height) {
      displayW = bufferSize.height;
      displayH = bufferSize.width;
    } else {
      displayW = bufferSize.width;
      displayH = bufferSize.height;
    }
    final aspect = displayH / displayW;

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
