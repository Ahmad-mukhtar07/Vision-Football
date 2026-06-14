/// Home-screen player identity shown in the profile strip.
class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.countryName,
    required this.position,
  });

  static const defaultDisplayName = 'Striker10';
  static const defaultCountryName = 'Argentina';
  static const defaultPosition = 'Striker';

  static const defaults = UserProfile(
    displayName: defaultDisplayName,
    countryName: defaultCountryName,
    position: defaultPosition,
  );

  final String displayName;
  final String countryName;
  final String position;

  UserProfile copyWith({
    String? displayName,
    String? countryName,
    String? position,
  }) {
    return UserProfile(
      displayName: displayName ?? this.displayName,
      countryName: countryName ?? this.countryName,
      position: position ?? this.position,
    );
  }
}

/// Common outfield / keeper roles for the profile position picker.
const List<String> kFootballPositions = [
  'Striker',
  'Winger',
  'Midfielder',
  'Defender',
  'Goalkeeper',
];
