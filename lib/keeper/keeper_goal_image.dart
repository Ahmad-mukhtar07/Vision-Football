import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Goal image rendered as a full-screen-height layer, showing only the
/// center vertical slice of the (horizontally wide) source asset.
///
/// The image is sized to match the screen height; everything wider than the
/// screen is clipped, which naturally leaves the central vertical chunk
/// visible.
///
/// Accepts either a static [horizontalShift] or a live [shiftListenable].
/// When the listenable is provided, only the inner [Transform.translate]
/// rebuilds when it changes — the heavy image / clip / overflow widgets are
/// kept stable.
class KeeperGoalImage extends StatelessWidget {
  const KeeperGoalImage({
    super.key,
    this.horizontalShift = 0.0,
    this.shiftListenable,
  });

  final double horizontalShift;
  final ValueListenable<double>? shiftListenable;

  static const String _asset = 'assets/goal/Inside-goal.png';

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
