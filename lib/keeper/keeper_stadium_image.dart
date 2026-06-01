import 'package:flutter/material.dart';

/// Stadium background for goalkeeper mode, rendered as a full-screen-height
/// image with only the center vertical slice visible.
///
/// Like [KeeperGoalImage], the horizontally wide image is fitted to the
/// screen height and clipped to the screen width, leaving excess on left
/// and right sides. A [horizontalShift] parameter is ready for future
/// camera-pan animation.
class KeeperStadiumImage extends StatelessWidget {
  const KeeperStadiumImage({
    super.key,
    this.horizontalShift = 0.0,
  });

  final double horizontalShift;

  static const String _asset =
      'assets/images/stadium/stadium-keeper-view.png';

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
