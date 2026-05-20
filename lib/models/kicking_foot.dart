/// Which leg the player will use to kick (anatomical left / right).
enum KickingFoot {
  left,
  right;

  bool get isLeft => this == KickingFoot.left;

  String get bodyLabel => isLeft ? 'Left foot' : 'Right foot';

  /// Front-camera preview is mirrored horizontally (selfie view).
  String get mirrorScreenHint => isLeft
      ? 'On the RIGHT side of your screen'
      : 'On the LEFT side of your screen';

  /// Maps a tap on the mirrored preview to the real kicking foot.
  static KickingFoot fromMirrorScreenSide({required bool isScreenLeft}) {
    return isScreenLeft ? KickingFoot.right : KickingFoot.left;
  }
}
