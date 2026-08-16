/// Team / player rating models for Quick Match (shooting mode).
///
/// Attributes are authored on a FIFA-style 0–100 scale for readability, and
/// exposed as normalized 0–1 multipliers (`*Norm`) for gameplay code so all
/// tuning of how a rating maps to ball physics lives in one place.
library;

import 'dart:ui' show Color;

/// A single outfield shooter and their shot attributes.
class Player {
  const Player({
    required this.name,
    required this.overall,
    required this.power,
    required this.accuracy,
    required this.curve,
    this.number,
  });

  final String name;

  /// Optional shirt number (cosmetic only).
  final int? number;

  /// Display overall rating (authored independently of stat breakdown). 0–100.
  final int overall;

  /// Shot force — ball pace + arc/distance. 0–100.
  final int power;

  /// Placement — how tightly the shot honors the player's aim. 0–100.
  final int accuracy;

  /// Swerve potential — how much spin the player can put on the ball. 0–100.
  final int curve;

  double get powerNorm => power / 100.0;
  double get accuracyNorm => accuracy / 100.0;
  double get curveNorm => curve / 100.0;
}

/// Goalkeeper rating for a team.
class GoalkeeperRating {
  const GoalkeeperRating({
    required this.name,
    required this.overall,
    required this.reflex,
    required this.prediction,
    this.number,
  });

  final String name;
  final int? number;

  /// Display overall rating (authored independently of stat breakdown). 0–100.
  final int overall;

  /// Reaction speed — how quickly the keeper commits to a dive. 0–100.
  final int reflex;

  /// Anticipation — how likely the keeper dives toward the real shot. 0–100.
  final int prediction;

  double get reflexNorm => reflex / 100.0;
  double get predictionNorm => prediction / 100.0;
}

/// An international team: 5 shooters + 1 keeper.
class Team {
  const Team({
    required this.name,
    required this.countryCode,
    required this.kitPrimaryColor,
    required this.overall,
    required this.shooters,
    required this.keeper,
  });

  final String name;

  /// ISO-3166 alpha-2 country code (e.g. 'BR'), used to render the flag.
  final String countryCode;

  /// Primary shirt color tinted onto the keeper-mode shooter kit overlay.
  final Color kitPrimaryColor;

  /// Display overall rating (authored independently of squad averages). 0–100.
  final int overall;

  /// Exactly five shooters, in shooting order.
  final List<Player> shooters;

  final GoalkeeperRating keeper;

  /// Average shooter attack rating (excludes keeper) — handy for sorting.
  int get attackRating {
    if (shooters.isEmpty) return 0;
    final sum = shooters.fold<int>(0, (s, p) => s + p.overall);
    return (sum / shooters.length).round();
  }
}
