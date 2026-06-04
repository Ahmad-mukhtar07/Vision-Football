import 'dart:async';
import 'package:flutter/material.dart';

import 'hand_detector_service.dart';
import 'keeper_glove_rotation.dart';
import 'keeper_preview_layout.dart';

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
    this.calibrationMode = false,
    this.calibrationFullscreen = false,
    this.calibrationHandsReady = true,
    this.goalMouthRect,
  });

  final ValueChanged<GlovePositions> onGlovesChanged;

  /// When true, glove positions are mapped into the calibration preview box
  /// (unmirrored video) instead of full-screen mirrored coordinates.
  final bool calibrationMode;

  /// Immersive edge-to-edge calibration — uses mirrored full-screen mapping.
  final bool calibrationFullscreen;

  /// When false during calibration, fixed hand targets are shown instead of
  /// glove art until both hands are tracked.
  final bool calibrationHandsReady;

  /// Goal mouth in screen pixels — used for gameplay glove rotation.
  final Rect? goalMouthRect;

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
        final usePreviewBox =
            widget.calibrationMode && !widget.calibrationFullscreen;
        final previewRect = usePreviewBox && _imageSize != null
            ? KeeperPreviewLayout.calibrationRect(size, _imageSize!)
            : null;
        final left = _toScreen(_leftNorm, size, previewRect);
        final right = _toScreen(_rightNorm, size, previewRect);
        // Push out the latest positions after layout so the game can read them.
        if (left != _leftScreen || right != _rightScreen) {
          _leftScreen = left;
          _rightScreen = right;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onGlovesChanged(GlovePositions(left: left, right: right));
          });
        }

        final showGloves = !widget.calibrationMode ||
            (widget.calibrationMode && widget.calibrationHandsReady);

        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (showGloves && left != null)
                _GloveMarker(
                  position: left,
                  isLeft: true,
                  screenSize: size,
                  goalMouthRect: widget.goalMouthRect,
                  calibrationReference: previewRect,
                  mirror: usePreviewBox,
                ),
              if (showGloves && right != null)
                _GloveMarker(
                  position: right,
                  isLeft: false,
                  screenSize: size,
                  goalMouthRect: widget.goalMouthRect,
                  calibrationReference: previewRect,
                  mirror: usePreviewBox,
                ),
            ],
          ),
        );
      },
    );
  }

  Offset? _toScreen(Offset? norm, Size screen, Rect? previewRect) {
    if (norm == null) return null;

    if (previewRect != null) {
      // Preview is unmirrored; detector coords are mirrored for gameplay.
      final nx = 1.0 - norm.dx;
      final ny = norm.dy;
      return Offset(
        previewRect.left + nx * previewRect.width,
        previewRect.top + ny * previewRect.height,
      );
    }

    return Offset(norm.dx * screen.width, norm.dy * screen.height);
  }
}

class _GloveMarker extends StatelessWidget {
  const _GloveMarker({
    required this.position,
    required this.isLeft,
    required this.screenSize,
    required this.goalMouthRect,
    required this.calibrationReference,
    this.mirror = false,
  });

  final Offset position;
  final bool isLeft;
  final Size screenSize;
  final Rect? goalMouthRect;
  final Rect? calibrationReference;

  /// Mirror the glove art horizontally (calibration shows an unmirrored feed,
  /// so the glove graphic must be flipped to match the player's real hands).
  final bool mirror;

  static const double _gloveHeight = 100;
  static const double _gloveWidth = 80;

  double _rotationAngle() {
    if (goalMouthRect != null) {
      return KeeperGloveRotation.forGameplay(
        position: position,
        screen: screenSize,
        goalMouth: goalMouthRect!,
      );
    }
    final ref = calibrationReference ??
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    return KeeperGloveRotation.forCalibration(
      position: position,
      referenceRect: ref,
    );
  }

  @override
  Widget build(BuildContext context) {
    final angle = _rotationAngle();

    final asset = isLeft
        ? 'assets/images/keeper/gloves/Keeper-glove-left.png'
        : 'assets/images/keeper/gloves/Keeper-glove-right.png';

    Widget glove = Image.asset(
      asset,
      width: _gloveWidth,
      height: _gloveHeight,
      fit: BoxFit.contain,
    );

    if (mirror) {
      glove = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scaleByDouble(-1.0, 1.0, 1.0, 1.0),
        child: glove,
      );
    }

    // Pivot at the bottom of the glove (wrist / reach point).
    return Positioned(
      left: position.dx - _gloveWidth / 2,
      top: position.dy - _gloveHeight,
      width: _gloveWidth,
      height: _gloveHeight,
      child: Transform.rotate(
        angle: mirror ? -angle : angle,
        alignment: Alignment.bottomCenter,
        child: glove,
      ),
    );
  }
}
