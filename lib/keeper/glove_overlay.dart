import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'hand_detector_service.dart';

/// On-screen positions of both glove markers in screen pixels.
class GlovePositions {
  const GlovePositions({this.left, this.right});
  final Offset? left;
  final Offset? right;
}

/// Renders two circular "glove" markers tracking the player's hands.
///
/// Listens to [HandDetectorService.handFrames] for normalized wrist
/// positions, applies a light smoothing pass to remove jitter, maps them
/// to screen pixels, and paints them as colored circles with a glove icon.
///
/// Pushes the latest screen positions out through [onGlovesChanged] so
/// the keeper game can run save/conceded checks at ball-arrival time.
class GloveOverlay extends StatefulWidget {
  const GloveOverlay({
    super.key,
    required this.onGlovesChanged,
  });

  final ValueChanged<GlovePositions> onGlovesChanged;

  @override
  State<GloveOverlay> createState() => _GloveOverlayState();
}

class _GloveOverlayState extends State<GloveOverlay> {
  StreamSubscription<HandFrame>? _sub;
  Offset? _leftNorm;
  Offset? _rightNorm;
  Offset? _leftScreen;
  Offset? _rightScreen;
  Size? _imageSize;

  static const double _smoothAlpha = 0.6;

  @override
  void initState() {
    super.initState();
    _sub = HandDetectorService.instance.handFrames.listen(_onFrame);
  }

  void _onFrame(HandFrame frame) {
    if (!mounted) return;
    _imageSize = frame.imageSize ?? _imageSize;
    _leftNorm = _smooth(_leftNorm, frame.leftHand);
    _rightNorm = _smooth(_rightNorm, frame.rightHand);
    setState(() {});
  }

  Offset? _smooth(Offset? prev, Offset? next) {
    if (next == null) return prev;
    if (prev == null) return next;
    return Offset(
      prev.dx + (next.dx - prev.dx) * _smoothAlpha,
      prev.dy + (next.dy - prev.dy) * _smoothAlpha,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final left = _toScreen(_leftNorm, size);
        final right = _toScreen(_rightNorm, size);
        // Push out the latest positions after layout so the game can read them.
        if (left != _leftScreen || right != _rightScreen) {
          _leftScreen = left;
          _rightScreen = right;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onGlovesChanged(GlovePositions(left: left, right: right));
          });
        }

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (left != null)
                _GloveMarker(
                    position: left, isLeft: true, screenWidth: size.width),
              if (right != null)
                _GloveMarker(
                    position: right, isLeft: false, screenWidth: size.width),
            ],
          ),
        );
      },
    );
  }

  Offset? _toScreen(Offset? norm, Size screen) {
    if (norm == null) return null;
    return Offset(norm.dx * screen.width, norm.dy * screen.height);
  }
}

class _GloveMarker extends StatelessWidget {
  const _GloveMarker({
    required this.position,
    required this.isLeft,
    required this.screenWidth,
  });

  final Offset position;
  final bool isLeft;
  final double screenWidth;

  static const double _gloveHeight = 100;
  static const double _gloveWidth = 80;

  /// Max tilt in radians (~20 degrees).
  static const double _maxTilt = 20 * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    // Normalized position: -1 (left edge) to +1 (right edge).
    final nx = screenWidth > 0
        ? (position.dx / screenWidth) * 2.0 - 1.0
        : 0.0;
    final tilt = nx * _maxTilt;

    final asset = isLeft
        ? 'assets/images/keeper/gloves/Keeper-glove-left.png'
        : 'assets/images/keeper/gloves/Keeper-glove-right.png';

    return Positioned(
      left: position.dx - _gloveWidth / 2,
      top: position.dy - _gloveHeight / 2,
      width: _gloveWidth,
      height: _gloveHeight,
      child: Transform.rotate(
        angle: tilt,
        child: Image.asset(
          asset,
          width: _gloveWidth,
          height: _gloveHeight,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
