import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/game_settings.dart';
import '../layout_constants.dart';
import '../match_state.dart';
import '../painters/stadium_painter.dart';

/// Stadium crowd background (animated GIF; fills upper screen behind goal/keeper).
class SkyBackgroundComponent extends PositionComponent {
  SkyBackgroundComponent({required GameLayout layout})
      : _layout = layout,
        super(
          position: Vector2.zero(),
          anchor: Anchor.topLeft,
        );

  final GameLayout _layout;
  final List<ui.Image> _frames = [];
  final List<Duration> _frameDurations = [];
  int _currentFrame = 0;
  double _frameTimer = 0;
  double _crowdZoom = 1.0;

  set crowdZoom(double z) => _crowdZoom = z;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadGifFrames(GameSettings.keeperStadium.shootingAssetPath);
  }

  static const double _minFrameSeconds = 0.1; // GIF delay 0 → 100 ms per spec.

  double _frameDurationSeconds(int index) {
    final seconds = _frameDurations[index].inMilliseconds / 1000.0;
    return seconds > 0 ? seconds : _minFrameSeconds;
  }

  Future<void> _loadGifFrames(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());

    for (var i = 0; i < codec.frameCount; i++) {
      final frameInfo = await codec.getNextFrame();
      _frames.add(frameInfo.image);
      _frameDurations.add(frameInfo.duration);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_frames.length <= 1) return;

    _frameTimer += dt;
    var duration = _frameDurationSeconds(_currentFrame);
    while (_frameTimer >= duration) {
      _frameTimer -= duration;
      _currentFrame = (_currentFrame + 1) % _frames.length;
      duration = _frameDurationSeconds(_currentFrame);
    }
  }

  @override
  void render(Canvas canvas) {
    if (_frames.isEmpty) return;

    final img = _frames[_currentFrame];
    final w = _layout.width;
    final h = _layout.height * StadiumVisualLayout.pitchBandTop;

    size = Vector2(w, h);
    position = Vector2.zero();

    final imgW = img.width.toDouble();
    final imgH = img.height.toDouble();

    Rect srcRect;
    if (_crowdZoom > 1.0) {
      final cropW = imgW / _crowdZoom;
      final cropH = imgH / _crowdZoom;
      // Anchor crop to bottom so the pitch horizon is not clipped when zooming in.
      srcRect = Rect.fromLTWH(
        (imgW - cropW) / 2,
        imgH - cropH,
        cropW,
        cropH,
      );
    } else {
      srcRect = Rect.fromLTWH(0, 0, imgW, imgH);
    }

    final destRect = Rect.fromLTWH(0, 0, w, h);
    canvas.drawImageRect(img, srcRect, destRect, Paint());
  }

  @override
  void onRemove() {
    for (final frame in _frames) {
      frame.dispose();
    }
    _frames.clear();
    super.onRemove();
  }
}

/// Stadium pitch band (cached, below camera window).
class PitchBackgroundComponent extends PositionComponent {
  PitchBackgroundComponent({required GameLayout layout})
      : _layout = layout,
        super(
          anchor: Anchor.topLeft,
        );

  final GameLayout _layout;
  ui.Picture? _cachedPicture;
  Vector2? _cachedSize;
  ShotType _shotType = ShotType.penalty;
  double _ballSpawnY = 0;
  double _goalBottomY = 0;
  double _visualScale = 1.0;

  set shotType(ShotType value) {
    if (value == _shotType) return;
    _shotType = value;
    _invalidateCache();
  }

  set ballSpawnY(double y) {
    if (y == _ballSpawnY) return;
    _ballSpawnY = y;
    _invalidateCache();
  }

  set goalBottomY(double y) {
    if (y == _goalBottomY) return;
    _goalBottomY = y;
    _invalidateCache();
  }

  set visualScale(double s) {
    if (s == _visualScale) return;
    _visualScale = s;
    _invalidateCache();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _invalidateCache();
  }

  void _invalidateCache() {
    _cachedPicture?.dispose();
    _cachedPicture = null;
    _cachedSize = null;
  }

  void _ensureCache() {
    final w = _layout.width;
    final h = _layout.height * StadiumVisualLayout.pitchBandHeight;
    final top = _layout.height * StadiumVisualLayout.pitchBandTop;
    final newSize = Vector2(w, h);
    if (_cachedPicture != null && _cachedSize == newSize) return;

    _cachedPicture?.dispose();
    size = newSize;
    position = Vector2(0, top);

    final spawnX = _layout.ballSpawn.x;
    final spawnY = _ballSpawnY > 0 ? _ballSpawnY : _layout.ballSpawn.y;
    final effectiveGoalBottomY = _goalBottomY > 0 ? _goalBottomY : _layout.goalRect.bottom;
    final painter = StadiumPitchPainter(
      size: Size(w, h),
      fullScreenWidth: w,
      fullScreenHeight: _layout.height,
      ballSpawnX: spawnX,
      ballSpawnY: spawnY,
      goalRect: _layout.goalRect,
      goalBottomY: effectiveGoalBottomY,
      visualScale: _visualScale,
      isFreeKick: _shotType == ShotType.freeKick,
    );
    _cachedPicture = recordStaticPicture(painter, Size(w, h));
    _cachedSize = newSize;
  }

  @override
  void render(Canvas canvas) {
    _ensureCache();
    if (_cachedPicture != null) {
      canvas.drawPicture(_cachedPicture!);
    }
  }

  @override
  void onRemove() {
    _cachedPicture?.dispose();
    super.onRemove();
  }
}
