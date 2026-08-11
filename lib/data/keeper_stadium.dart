/// Keeper-mode stadium backgrounds selectable before a match.
enum KeeperStadiumLocation {
  usa,
  italy,
  spain;

  String get label => switch (this) {
        KeeperStadiumLocation.usa => 'USA',
        KeeperStadiumLocation.italy => 'Italy',
        KeeperStadiumLocation.spain => 'Spain',
      };

  String get assetPath => switch (this) {
        KeeperStadiumLocation.usa =>
          'assets/images/stadium/stadium-keeper-view-us.png',
        KeeperStadiumLocation.italy =>
          'assets/images/stadium/stadium-keeper-view-italy.png',
        KeeperStadiumLocation.spain =>
          'assets/images/stadium/stadium-keeper-view-spain.png',
      };
}
