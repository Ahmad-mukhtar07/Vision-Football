import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../layout_constants.dart';
import '../painters/stadium_painter.dart';

/// Stadium crowd background (image-based; fills upper screen behind goal/keeper).
class SkyBackgroundComponent extends PositionComponent {
  SkyBackgroundComponent({required GameLayout layout})
      : _layout = layout,
        super(
          position: Vector2.zero(),
          anchor: Anchor.topLeft,
        );

  final GameLayout _layout;
  ui.Image? _crowdImage;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _crowdImage = await _loadImage('assets/images/stadium_crowd.png');
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  @override
  void render(Canvas canvas) {
    final img = _crowdImage;
    if (img == null) return;

    final w = _layout.width;
    final h = _layout.height * StadiumVisualLayout.pitchBandTop;

    size = Vector2(w, h);
    position = Vector2.zero();

    final srcRect = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final destRect = Rect.fromLTWH(0, 0, w, h);

    canvas.drawImageRect(img, srcRect, destRect, Paint());
  }

  @override
  void onRemove() {
    _crowdImage?.dispose();
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

    final spawn = _layout.ballSpawn;
    final painter = StadiumPitchPainter(
      size: Size(w, h),
      fullScreenWidth: w,
      fullScreenHeight: _layout.height,
      ballSpawnX: spawn.x,
      ballSpawnY: spawn.y,
      goalRect: _layout.goalRect,
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
