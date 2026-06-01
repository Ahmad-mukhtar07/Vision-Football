import 'dart:math';
import 'dart:ui';

import 'package:flame/cache.dart';

/// Shared PNG football sprites used in keeper and shooting modes.
class BallSprite {
  BallSprite._();

  static const leftAsset = 'ball/Ball-left.png';
  static const rightAsset = 'ball/Ball-right.png';
  static const spinSpeed = 20.0; // radians per second

  static Future<({Image left, Image right})> loadImages(Images images) async {
    final left = await images.load(leftAsset);
    final right = await images.load(rightAsset);
    return (left: left, right: right);
  }

  /// Hard-swap between left/right views every half spin — no blending.
  static void draw(
    Canvas canvas, {
    required Offset center,
    required double radius,
    required Image left,
    required Image right,
    required double spinAngle,
    required bool movingRight,
    double opacity = 1.0,
    Color? tintColor,
  }) {
    if (opacity <= 0.01) return;

    final diameter = radius * 2;
    final ballBounds = Rect.fromCircle(center: center, radius: radius);

    final primary = movingRight ? right : left;
    final secondary = movingRight ? left : right;
    final img = sin(spinAngle) >= 0 ? primary : secondary;

    final paint = Paint();
    if (tintColor != null) {
      paint.colorFilter = ColorFilter.mode(tintColor, BlendMode.modulate);
    } else if (opacity < 1.0) {
      paint.color = Color.fromRGBO(255, 255, 255, opacity);
      paint.colorFilter = ColorFilter.mode(paint.color, BlendMode.modulate);
    }

    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = Rect.fromCenter(
      center: center,
      width: diameter,
      height: diameter,
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(ballBounds));
    canvas.drawImageRect(img, src, dst, paint);
    canvas.restore();
  }
}
