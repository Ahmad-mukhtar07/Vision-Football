/// Keeper-mode stadium backgrounds selectable before a match.
enum KeeperStadiumLocation {
  italy,
  spain,
  usa;

  String get label => switch (this) {
        KeeperStadiumLocation.usa => 'USA',
        KeeperStadiumLocation.italy => 'Italy',
        KeeperStadiumLocation.spain => 'Spain',
      };

  String get assetPath => switch (this) {
        KeeperStadiumLocation.usa =>
          'assets/images/stadium/keeping/stadium-keeper-view-us.png',
        KeeperStadiumLocation.italy =>
          'assets/images/stadium/keeping/stadium-keeper-view-italy.png',
        KeeperStadiumLocation.spain =>
          'assets/images/stadium/keeping/stadium-keeper-view-spain.png',
      };

  /// Animated crowd background for shooting mode.
  String get shootingAssetPath => switch (this) {
        KeeperStadiumLocation.italy =>
          'assets/images/stadium/shooting/Stadium-shooter-view-Italy.gif',
        KeeperStadiumLocation.spain =>
          'assets/images/stadium/shooting/Stadium-shooter-view-Spain.gif',
        KeeperStadiumLocation.usa =>
          'assets/images/stadium/shooting/Stadium-shooter-view-US.gif',
      };
}
