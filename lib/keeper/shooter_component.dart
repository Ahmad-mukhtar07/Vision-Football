import 'dart:ui';

import 'package:flame/components.dart';

import 'keeper_game.dart';

enum _ShooterPhase { idle, kicking, recovery }

/// Penalty-taker sprite with a custom 7-frame, non-looping kick timeline.
class ShooterComponent extends PositionComponent
    with HasGameReference<KeeperGame> {
  ShooterComponent({required this.area}) : super(priority: 0);

  final Vector2 area;

  static const List<String> _frameAssets = [
    'shooter/Player-IdlePosition.png',
    'shooter/Player-Right-RunUp.png',
    'shooter/Player-Left-RunUp.png',
    'shooter/Player-Backswing.png',
    'shooter/Player-Impact.png',
    'shooter/Player-FollowThrough.png',
    'shooter/Player-Recovery.png',
  ];

  /// Durations for kick frames 1–5 (right run-up through follow-through).
  static const List<double> _segmentDurations = [
    0.10, // 1 — right run-up
    0.10, // 2 — left run-up  (~200 ms approach)
    0.09, // 3 — backswing hold
    0.016, // 4 — impact (ball launches on enter)
    0.15, // 5 — follow-through
  ];

  /// Foot line on the pitch (lower on screen = planted on grass).
  static const double _emitYFraction = 0.62;

  /// Ball sits on the turf, slightly toward the goal from the foot line.
  static const double _ballOffsetY = 20;
  static const double _ballOffsetTowardGoal = -10;

  /// Base sprite height at full scale (run-up ends at [_approachScaleEnd]).
  static const double _spriteHeightFraction = 0.22;

  /// Smallest at idle / first run-up step; grows as the player approaches.
  static const double _approachScaleStart = 0.76;
  static const double _approachScaleEnd = 1.0;

  final List<Image?> _frames = List.filled(7, null);

  _ShooterPhase _phase = _ShooterPhase.idle;
  int _frameIndex = 0;
  double _segmentTimer = 0;
  bool _ballLaunched = false;

  /// Fixed penalty-spot position in front of the player (screen center).
  ///
  /// Does not include camera pan — the spot stays centered between rounds
  /// while the stadium alone pans during flight.
  Offset get ballEmitPoint => Offset(
        area.x * 0.5,
        area.y * _emitYFraction + _ballOffsetY + _ballOffsetTowardGoal,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (var i = 0; i < _frameAssets.length; i++) {
      _frames[i] = await game.images.load(_frameAssets[i]);
    }
  }

  void resetToIdle() {
    _phase = _ShooterPhase.idle;
    _frameIndex = 0;
    _segmentTimer = 0;
    _ballLaunched = false;
  }

  /// Starts the run-up → strike → recovery sequence (frames 1–6).
  void beginKickSequence() {
    if (_phase != _ShooterPhase.idle) return;
    if (_frames[1] == null) return;
    _phase = _ShooterPhase.kicking;
    _frameIndex = 1;
    _segmentTimer = 0;
    _ballLaunched = false;
  }

  double _visualScaleForFrame(int index) {
    if (index <= 0) return _approachScaleStart;
    if (index >= 5) return _approachScaleEnd;
    // Frames 1–4: step up in size through the run-up and strike.
    final t = index / 4.0;
    return _approachScaleStart +
        (_approachScaleEnd - _approachScaleStart) * t;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_phase != _ShooterPhase.kicking) return;
    if (_frameIndex >= 6) return;

    final durationIndex = _frameIndex - 1;
    _segmentTimer += dt;
    if (_segmentTimer < _segmentDurations[durationIndex]) return;

    _segmentTimer = 0;
    _goToFrame(_frameIndex + 1);
  }

  void _goToFrame(int index) {
    _frameIndex = index;

    if (index == 4 && !_ballLaunched) {
      _ballLaunched = true;
      game.launchShot();
    }

    if (index >= 6) {
      _phase = _ShooterPhase.recovery;
      _frameIndex = 6;
      _segmentTimer = 0;
    }
  }

  @override
  void render(Canvas canvas) {
    final img = _frames[_frameIndex];
    if (img == null) return;

    // Parallax only while the ball is in play; penalty spot stays centered.
    final panX = game.ballUsesCameraParallax ? game.cameraXOffset.value : 0.0;
    final foot = Offset(area.x * 0.5 + panX, area.y * _emitYFraction);
    final scale = _visualScaleForFrame(_frameIndex);
    final height = area.y * _spriteHeightFraction * scale;
    final width = height * (img.width / img.height);

    final dst = Rect.fromLTWH(
      foot.dx - width * 0.5,
      foot.dy - height,
      width,
      height,
    );

    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    _drawGroundShadow(canvas, foot, scale);
    canvas.drawImageRect(img, src, dst, Paint());
  }

  void _drawGroundShadow(Canvas canvas, Offset foot, double scale) {
    final shadowWidth = area.x * 0.13 * scale;
    final shadowHeight = shadowWidth * 0.26;
    final shadowRect = Rect.fromCenter(
      center: Offset(foot.dx, foot.dy + 6),
      width: shadowWidth,
      height: shadowHeight,
    );

    canvas.drawOval(
      shadowRect,
      Paint()
        ..color = const Color(0x52000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
  }
}
