import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../layout_constants.dart';
import '../painters/stadium_painter.dart';

/// Stadium sky / stands band (cached, above camera window).
class SkyBackgroundComponent extends PositionComponent {
  SkyBackgroundComponent({required GameLayout layout})
      : _layout = layout,
        super(
          position: Vector2.zero(),
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
    final h = _layout.height * StadiumVisualLayout.skyBandHeight;
    final newSize = Vector2(w, h);
    if (_cachedPicture != null && _cachedSize == newSize) return;

    _cachedPicture?.dispose();
    size = newSize;
    position = Vector2.zero();

    final painter = StadiumSkyPainter(
      size: Size(w, h),
      fullScreenHeight: _layout.height,
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
