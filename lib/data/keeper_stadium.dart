/// Keeper-mode stadium backgrounds selectable before a match.
enum KeeperStadiumLocation {
  brazil,
  italy,
  spain,
  usa;

  String get label => switch (this) {
        KeeperStadiumLocation.brazil => 'Brazil',
        KeeperStadiumLocation.italy => 'Italy',
        KeeperStadiumLocation.spain => 'Spain',
        KeeperStadiumLocation.usa => 'USA',
      };

  String get assetPath => switch (this) {
        KeeperStadiumLocation.brazil =>
          'assets/images/stadium/keeping/stadium-keeper-view-brazil.png',
        KeeperStadiumLocation.italy =>
          'assets/images/stadium/keeping/stadium-keeper-view-italy.jpeg',
        KeeperStadiumLocation.spain =>
          'assets/images/stadium/keeping/stadium-keeper-view-spain.png',
        KeeperStadiumLocation.usa =>
          'assets/images/stadium/keeping/stadium-keeper-view-us.png',
      };

  /// Animated crowd background for shooting mode.
  String get shootingAssetPath => switch (this) {
        KeeperStadiumLocation.brazil =>
          'assets/images/stadium/shooting/Stadium-shooter-view-Brazil.gif',
        KeeperStadiumLocation.italy =>
          'assets/images/stadium/shooting/Stadium-shooter-view-Italy.gif',
        KeeperStadiumLocation.spain =>
          'assets/images/stadium/shooting/Stadium-shooter-view-Spain.gif',
        KeeperStadiumLocation.usa =>
          'assets/images/stadium/shooting/Stadium-shooter-view-US.gif',
      };
}
