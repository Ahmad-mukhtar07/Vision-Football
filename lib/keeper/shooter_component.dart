import 'dart:ui';

import 'package:flame/components.dart';

import 'keeper_game.dart';
import 'keeper_layout_constants.dart';

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

  /// Smallest at idle / first run-up step; grows as the player approaches.
  static const double _approachScaleStart = 0.76;
  static const double _approachScaleEnd = 1.0;

  final List<Image?> _frames = List.filled(7, null);

  KeeperSpotType _spotType = KeeperSpotType.penalty;
  _ShooterPhase _phase = _ShooterPhase.idle;
  int _frameIndex = 0;
  double _segmentTimer = 0;
  bool _ballLaunched = false;

  void applySpot(KeeperSpotType spot) {
    _spotType = spot;
  }

  double get _layoutScale => KeeperLayoutConstants.visualScale(_spotType);

  /// Live game viewport (avoids stale [area] after resize).
  Vector2 get _viewport => game.isLoaded ? game.size : area;

  double get _centerX =>
      _viewport.x *
      (0.5 + KeeperLayoutConstants.ballCenterXOffsetFraction);

  /// Ball centre on the pitch marking for the current spot.
  Offset get ballEmitPoint => Offset(
        _centerX,
        _viewport.y * KeeperLayoutConstants.ballYFraction(_spotType),
      );

  /// Bottom of the shooter sprite — slightly above the ball's lower edge.
  Offset get _footAnchor {
    final ball = ballEmitPoint;
    final r = KeeperLayoutConstants.ballRestRadius(_spotType);
    final lift =
        2 * r * KeeperLayoutConstants.shooterFootAboveBallFraction;
    return Offset(ball.dx, ball.dy + r - lift);
  }

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
    final layout = _layoutScale;
    if (index <= 0) return _approachScaleStart * layout;
    if (index >= 5) return _approachScaleEnd * layout;
    final t = index / 4.0;
    final approach = _approachScaleStart +
        (_approachScaleEnd - _approachScaleStart) * t;
    return approach * layout;
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

    final panX = game.tracksBallForCameraPan ? game.cameraXOffset.value : 0.0;
    final foot = Offset(_footAnchor.dx + panX, _footAnchor.dy);
    final scale = _visualScaleForFrame(_frameIndex);
    final height =
        _viewport.y * KeeperLayoutConstants.shooterHeightFraction * scale;
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
    final shadowWidth = _viewport.x * 0.13 * scale;
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
