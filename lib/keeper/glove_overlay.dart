import 'dart:async';

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
              if (left != null) _GloveMarker(position: left, isLeft: true),
              if (right != null) _GloveMarker(position: right, isLeft: false),
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
  const _GloveMarker({required this.position, required this.isLeft});

  final Offset position;
  final bool isLeft;

  static const double _radius = 36;

  @override
  Widget build(BuildContext context) {
    final color = isLeft
        ? const Color(0xFFFFB300) // amber for left
        : const Color(0xFF42A5F5); // blue for right
    return Positioned(
      left: position.dx - _radius,
      top: position.dy - _radius,
      width: _radius * 2,
      height: _radius * 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.85),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.6),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.sports_handball,
            color: Colors.white,
            size: 30,
          ),
        ),
      ),
    );
  }
}
