import 'package:flutter/material.dart';

/// Goal image rendered as a full-screen-height layer, showing only the
/// center vertical slice of the (horizontally wide) source asset.
///
/// The image is sized to match the screen height; everything wider than the
/// screen is clipped, which naturally leaves the central vertical chunk
/// visible. Later this overlay can be animated horizontally to pan the
/// camera view.
class KeeperGoalImage extends StatelessWidget {
  const KeeperGoalImage({
    super.key,
    this.horizontalShift = 0.0,
  });

  /// Horizontal pan offset (pixels). Positive shifts the image right,
  /// revealing the left side of the goal. Reserved for future animation.
  final double horizontalShift;

  static const String _asset = 'assets/goal/Inside-goal.png';

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return IgnorePointer(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: double.infinity,
          minWidth: 0,
          maxHeight: screen.height,
          minHeight: screen.height,
          child: Transform.translate(
            offset: Offset(horizontalShift, 0),
            child: Image.asset(
              _asset,
              height: screen.height,
              fit: BoxFit.fitHeight,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}
