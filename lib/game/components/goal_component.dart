import 'dart:async' as async;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout_constants.dart';
import '../painters/goal_painter.dart';

/// Goal frame and net at the top of the screen.
class GoalComponent extends PositionComponent {
  GoalComponent({required GameLayout layout})
      : _layout = layout,
        super(
          position: Vector2(layout.goalRect.left, layout.goalRect.top),
          size: Vector2(layout.goalRect.width, layout.goalRect.height),
          anchor: Anchor.topLeft,
        );

  final GameLayout _layout;

  GameLayout get layout => _layout;

  ui.Image? _goalImage;
  Rect? _destRect;
  double _flashOpacity = 0;
  double _visualScale = 1.0;
  final List<GoalParticle> _particles = [];
  async.Timer? _flashTimer;

  void applyVisualScale(double scale) {
    _visualScale = scale;
  }

  /// Screen-space Y where the goal image visually ends (accounting for
  /// letterboxing and visual scale).
  double get visualBottomY {
    final goalRect = _layout.goalRect;
    final cy = goalRect.top + size.y / 2;
    double localBottom = size.y;
    if (_destRect != null) {
      localBottom = _destRect!.bottom;
    }
    final distFromCenter = localBottom - size.y / 2;
    return cy + distFromCenter * _visualScale;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _goalImage = await _loadImage('assets/images/goal_post.png');
    _computeDestRect();
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _computeDestRect() {
    final img = _goalImage;
    if (img == null) return;

    final imageAspect = img.width / img.height;
    final boxAspect = size.x / size.y;

    if (imageAspect > boxAspect) {
      final h = size.x / imageAspect;
      _destRect = Rect.fromLTWH(0, (size.y - h) / 2, size.x, h);
    } else {
      final w = size.y * imageAspect;
      _destRect = Rect.fromLTWH((size.x - w) / 2, 0, w, size.y);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final p in _particles) {
      p.life += dt;
    }
    _particles.removeWhere((p) => p.isDead);

    if (_flashOpacity > 0) {
      _flashOpacity = (_flashOpacity - dt * 2.5).clamp(0, 1);
    }
  }

  @override
  void render(Canvas canvas) {
    final img = _goalImage;
    final dest = _destRect;

    canvas.save();
    final cx = size.x / 2;
    final cy = size.y / 2;
    canvas.translate(cx, cy);
    canvas.scale(_visualScale, _visualScale);
    canvas.translate(-cx, -cy);

    if (img != null && dest != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        img.width.toDouble(),
        img.height.toDouble(),
      );
      canvas.drawImageRect(img, srcRect, dest, Paint());

      if (_flashOpacity > 0) {
        canvas.drawRect(
          dest,
          Paint()
            ..color = Colors.white.withValues(alpha: _flashOpacity * 0.6)
            ..blendMode = BlendMode.srcOver,
        );
      }
    }

    if (_particles.isNotEmpty) {
      paintGoalParticles(canvas, _particles);
    }

    canvas.restore();
  }

  bool containsScreenPoint(Offset point) => _layout.goalRect.contains(point);

  /// Visual celebration on goal (flash + particles). API unchanged for callers.
  void flashColor(Color color, Duration duration, {Offset? particleOrigin}) {
    _flashTimer?.cancel();
    _flashOpacity = 0.8;
    if (particleOrigin != null) {
      final local = particleOrigin - Offset(position.x, position.y);
      _particles.addAll(GoalParticle.burst(local));
    }
    _flashTimer = async.Timer(const Duration(milliseconds: 300), () {
      _flashOpacity = 0;
      _flashTimer = null;
    });
  }

  @override
  void onRemove() {
    _flashTimer?.cancel();
    super.onRemove();
  }
}
