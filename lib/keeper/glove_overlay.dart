import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/game_settings.dart';
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
    this.cameraXOffset,
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

  /// Hard-mode camera pan. Gloves render in world space (shifted with the
  /// scene) while [onGlovesChanged] still receives unshifted world positions.
  final ValueListenable<double>? cameraXOffset;

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

  // One latency-compensating tracker per hand.
  final _LatencyCompensatedTracker _leftTracker = _LatencyCompensatedTracker();
  final _LatencyCompensatedTracker _rightTracker = _LatencyCompensatedTracker();

  @override
  void initState() {
    super.initState();
    _sub = HandDetectorService.instance.handFrames.listen(_onFrame);
  }

  void _onFrame(HandFrame frame) {
    if (!mounted) return;
    _imageSize = frame.imageSize ?? _imageSize;
    _leftNorm = _leftTracker.update(frame.leftHand, frame.timestamp);
    _rightNorm = _rightTracker.update(frame.rightHand, frame.timestamp);
    setState(() {});
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

        final useWorldParallax = !widget.calibrationMode &&
            GameSettings.isHardMode &&
            widget.cameraXOffset != null;

        Widget gloveStack({double panX = 0}) {
          Offset? renderPos(Offset? world) =>
              world == null ? null : Offset(world.dx + panX, world.dy);
          final renderLeft = renderPos(left);
          final renderRight = renderPos(right);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (showGloves && renderLeft != null)
                _GloveMarker(
                  position: renderLeft,
                  worldPosition: left!,
                  isLeft: true,
                  screenSize: size,
                  goalMouthRect: widget.goalMouthRect,
                  calibrationReference: previewRect,
                  mirror: usePreviewBox,
                ),
              if (showGloves && renderRight != null)
                _GloveMarker(
                  position: renderRight,
                  worldPosition: right!,
                  isLeft: false,
                  screenSize: size,
                  goalMouthRect: widget.goalMouthRect,
                  calibrationReference: previewRect,
                  mirror: usePreviewBox,
                ),
            ],
          );
        }

        if (useWorldParallax) {
          return IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: widget.cameraXOffset!,
              builder: (context, panX, _) => gloveStack(panX: panX),
            ),
          );
        }

        return IgnorePointer(child: gloveStack());
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
    required this.worldPosition,
    required this.isLeft,
    required this.screenSize,
    required this.goalMouthRect,
    required this.calibrationReference,
    this.mirror = false,
  });

  /// Screen position after camera pan (rendering).
  final Offset position;

  /// World position for gameplay rotation (unaffected by camera pan).
  final Offset worldPosition;
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
        position: worldPosition,
        screen: screenSize,
        goalMouth: goalMouthRect!,
      );
    }
    final ref = calibrationReference ??
        Rect.fromLTWH(0, 0, screenSize.width, screenSize.height);
    return KeeperGloveRotation.forCalibration(
      position: worldPosition,
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

/// Tracks one hand's normalized position and projects it slightly forward
/// along its recent velocity, cancelling most of the camera→ML Kit→render
/// latency so the glove keeps up with fast dives instead of trailing behind.
///
/// A short, capped lead avoids overshoot, and velocity is smoothed so a single
/// noisy sample can't fling the glove away. When the hand isn't detected the
/// last position is held while the velocity bleeds off.
class _LatencyCompensatedTracker {
  Offset? _pos; // smoothed, latency-compensated output
  Offset? _lastRaw; // previous raw sample
  DateTime? _lastTime;
  Offset _velocity = Offset.zero; // normalized units per second

  /// How aggressively the output snaps toward the predicted target.
  static const double _positionAlpha = 0.7;

  /// Smoothing applied to the per-frame velocity estimate.
  static const double _velocityAlpha = 0.5;

  /// Seconds to project ahead (≈ one detection interval) to cancel latency.
  static const double _minLead = 0.03;
  static const double _maxLead = 0.08;

  /// Max distance (normalized) the prediction may deviate from the raw sample.
  static const double _maxLeadDistance = 0.10;

  Offset? update(Offset? raw, DateTime now) {
    if (raw == null) {
      _velocity = _velocity * 0.5;
      _lastRaw = null; // re-initialize cleanly when the hand reappears
      _lastTime = null;
      return _pos;
    }

    final last = _lastRaw;
    final lastTime = _lastTime;
    _lastRaw = raw;
    _lastTime = now;

    if (_pos == null || last == null || lastTime == null) {
      _pos = raw;
      _velocity = Offset.zero;
      return _pos;
    }

    final dt =
        (now.difference(lastTime).inMicroseconds / 1e6).clamp(0.005, 0.1);
    final instantaneous = (raw - last) / dt;
    _velocity = _velocity + (instantaneous - _velocity) * _velocityAlpha;

    final lead = dt.clamp(_minLead, _maxLead);
    var predicted = raw + _velocity * lead;

    // Cap how far ahead of the real sample we allow the glove to sit.
    final deviation = predicted - raw;
    final distance = deviation.distance;
    if (distance > _maxLeadDistance) {
      predicted = raw + deviation * (_maxLeadDistance / distance);
    }

    final prev = _pos!;
    _pos = prev + (predicted - prev) * _positionAlpha;
    return _pos;
  }
}
