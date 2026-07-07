import 'dart:math';

import '../data/game_settings.dart';
import '../keeper/keeper_layout_constants.dart';
import 'match_state.dart';

/// Builds a fixed penalty / free-kick sequence for a match. The first kick is
/// always a penalty; the remaining slots get a random count of free kicks
/// within the mode's min/max, placed in random order.
class ShotTypeSchedule {
  ShotTypeSchedule._();

  /// Shooting mode — how many of the [totalKicks] are free kicks.
  static List<ShotType> forShooting({
    required DifficultyMode mode,
    required int totalKicks,
    Random? random,
  }) {
    final (minFk, maxFk) = switch (mode) {
      DifficultyMode.easy => (1, 2),
      DifficultyMode.hard => (2, 3),
    };
    return _build(minFk, maxFk, totalKicks, random ?? Random())
        .map((isFreeKick) => isFreeKick ? ShotType.freeKick : ShotType.penalty)
        .toList();
  }

  /// Keeping mode — inverted free-kick counts vs shooting for the same mode.
  static List<KeeperSpotType> forKeeping({
    required DifficultyMode mode,
    required int totalKicks,
    Random? random,
  }) {
    final (minFk, maxFk) = switch (mode) {
      DifficultyMode.easy => (2, 3),
      DifficultyMode.hard => (1, 2),
    };
    return _build(minFk, maxFk, totalKicks, random ?? Random())
        .map((isFreeKick) =>
            isFreeKick ? KeeperSpotType.freeKick : KeeperSpotType.penalty)
        .toList();
  }

  /// Index 0 is always penalty. Among the remaining [totalKicks - 1] slots,
  /// exactly [freeCount] free kicks are placed at random positions.
  static List<bool> _build(
    int minFk,
    int maxFk,
    int totalKicks,
    Random random,
  ) {
    assert(totalKicks >= 1);
    final remaining = totalKicks - 1;
    final clampedMin = minFk.clamp(0, remaining);
    final clampedMax = maxFk.clamp(clampedMin, remaining);
    final freeCount =
        clampedMin + (clampedMax > clampedMin ? random.nextInt(clampedMax - clampedMin + 1) : 0);

    final slots = List<bool>.filled(totalKicks, false);
    if (freeCount > 0 && remaining > 0) {
      final indices = List.generate(remaining, (i) => i + 1)..shuffle(random);
      for (var i = 0; i < freeCount; i++) {
        slots[indices[i]] = true;
      }
    }
    return slots;
  }
}
