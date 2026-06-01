import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Stadium background for goalkeeper mode, rendered as a full-screen-height
/// image with only the center vertical slice visible.
///
/// The horizontally wide image is fitted to the screen height and clipped
/// to the screen width, leaving excess on both sides for the camera pan.
///
/// Accepts either a static [horizontalShift] or a live [shiftListenable].
/// When the listenable is provided, only the inner [Transform.translate]
/// rebuilds when it changes — the image, clip rect, and overflow box are
/// kept stable to avoid expensive per-frame rebuilds.
class KeeperStadiumImage extends StatelessWidget {
  const KeeperStadiumImage({
    super.key,
    this.horizontalShift = 0.0,
    this.shiftListenable,
  });

  final double horizontalShift;
  final ValueListenable<double>? shiftListenable;

  static const String _asset =
      'assets/images/stadium/stadium-keeper-view.png';

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final image = Image.asset(
      _asset,
      height: screen.height,
      fit: BoxFit.fitHeight,
      filterQuality: FilterQuality.medium,
    );

    final listenable = shiftListenable;
    final shiftedChild = listenable == null
        ? Transform.translate(
            offset: Offset(horizontalShift, 0),
            child: image,
          )
        : ValueListenableBuilder<double>(
            valueListenable: listenable,
            builder: (context, shift, child) => Transform.translate(
              offset: Offset(shift, 0),
              child: child,
            ),
            child: image,
          );

    return IgnorePointer(
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          maxWidth: double.infinity,
          minWidth: 0,
          maxHeight: screen.height,
          minHeight: screen.height,
          child: shiftedChild,
        ),
      ),
    );
  }
}
