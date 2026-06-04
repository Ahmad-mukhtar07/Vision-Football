import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Draws a black-background outline PNG over video using [BlendMode.lighten]
/// so only the golden lines are visible.
class OutlineImageOverlay extends StatefulWidget {
  const OutlineImageOverlay({super.key, required this.assetPath});

  final String assetPath;

  @override
  State<OutlineImageOverlay> createState() => _OutlineImageOverlayState();
}

class _OutlineImageOverlayState extends State<OutlineImageOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(covariant OutlineImageOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _image = null;
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(widget.assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _OutlineImagePainter(image),
      size: Size.infinite,
    );
  }
}

class _OutlineImagePainter extends CustomPainter {
  _OutlineImagePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final scale = math.min(size.width / src.width, size.height / src.height);
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: src.width * scale,
      height: src.height * scale,
    );

    final paint = Paint()
      ..blendMode = BlendMode.lighten
      ..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _OutlineImagePainter oldDelegate) =>
      oldDelegate.image != image;
}
