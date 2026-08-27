import 'package:shared_preferences/shared_preferences.dart';

import '../tournament/tournament_models.dart';

/// Snapshot of the player's energy drink inventory after regen is applied.
class EnergyDrinkState {
  const EnergyDrinkState({
    required this.count,
    required this.max,
    this.nextRefillAt,
  });

  final int count;
  final int max;
  final DateTime? nextRefillAt;

  bool get isFull => count >= max;

  Duration? get timeUntilNextRefill {
    final at = nextRefillAt;
    if (at == null || isFull) return null;
    final remaining = at.difference(DateTime.now());
    if (remaining.isNegative) return Duration.zero;
    return remaining;
  }
}

/// Persists energy drinks and their timed refill queue.
class EnergyDrinkStore {
  EnergyDrinkStore._();

  static const _keyCount = 'energy_drink_count';
  static const _keyNextRefillMs = 'energy_drink_next_refill_ms';

  static const maxDrinks = 12;
  static const defaultDrinks = 12;
  static const refillDuration = Duration(minutes: 15);

  static const fullMatchCost = 3;
  static const tournamentGroupCost = 3;
  static const tournamentKnockoutCost = 5;
  static const rewardedDrinkAmount = 5;
  static const lowEnergyThreshold = 6;

  static int costForTournamentRound(TournamentRound round) {
    if (round == TournamentRound.groupStage) return tournamentGroupCost;
    return tournamentKnockoutCost;
  }

  static Future<EnergyDrinkState> loadState() async {
    final prefs = await SharedPreferences.getInstance();
    var count = prefs.getInt(_keyCount) ?? defaultDrinks;
    final nextRefillMs = prefs.getInt(_keyNextRefillMs);
    var nextRefillAt = nextRefillMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(nextRefillMs);

    count = _applyRegeneration(count, nextRefillAt, (updatedAt) {
      nextRefillAt = updatedAt;
    });

    await _save(count: count, nextRefillAt: nextRefillAt);
    return EnergyDrinkState(
      count: count,
      max: maxDrinks,
      nextRefillAt: nextRefillAt,
    );
  }

  static Future<bool> canAfford(int cost) async {
    final state = await loadState();
    return state.count >= cost;
  }

  static Future<bool> tryConsume(int cost) async {
    final prefs = await SharedPreferences.getInstance();
    var count = prefs.getInt(_keyCount) ?? defaultDrinks;
    final nextRefillMs = prefs.getInt(_keyNextRefillMs);
    var nextRefillAt = nextRefillMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(nextRefillMs);

    count = _applyRegeneration(count, nextRefillAt, (updatedAt) {
      nextRefillAt = updatedAt;
    });

    if (count < cost) {
      await _save(count: count, nextRefillAt: nextRefillAt);
      return false;
    }

    count -= cost;
    if (count < maxDrinks && nextRefillAt == null) {
      nextRefillAt = DateTime.now().add(refillDuration);
    }

    await _save(count: count, nextRefillAt: nextRefillAt);
    return true;
  }

  static Future<void> resetToDefault() async {
    await _save(count: defaultDrinks, nextRefillAt: null);
  }

  /// QA override — sets stock directly (clamped to [0, maxDrinks]).
  static Future<EnergyDrinkState> addRewardDrinks(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    var count = prefs.getInt(_keyCount) ?? defaultDrinks;
    final nextRefillMs = prefs.getInt(_keyNextRefillMs);
    var nextRefillAt = nextRefillMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(nextRefillMs);

    count = _applyRegeneration(count, nextRefillAt, (updatedAt) {
      nextRefillAt = updatedAt;
    });

    count = (count + amount).clamp(0, maxDrinks);
    if (count >= maxDrinks) {
      nextRefillAt = null;
    } else if (nextRefillAt == null) {
      nextRefillAt = DateTime.now().add(refillDuration);
    }

    await _save(count: count, nextRefillAt: nextRefillAt);
    return loadState();
  }

  static Future<EnergyDrinkState> setCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    var nextRefillMs = prefs.getInt(_keyNextRefillMs);
    var nextRefillAt = nextRefillMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(nextRefillMs);
    final clamped = count.clamp(0, maxDrinks);
    if (clamped >= maxDrinks) {
      nextRefillAt = null;
    } else if (nextRefillAt == null) {
      nextRefillAt = DateTime.now().add(refillDuration);
    }
    await _save(count: clamped, nextRefillAt: nextRefillAt);
    return loadState();
  }

  static int _applyRegeneration(
    int count,
    DateTime? nextRefillAt,
    void Function(DateTime? updatedAt) onNextRefillUpdated,
  ) {
    if (count >= maxDrinks) {
      onNextRefillUpdated(null);
      return maxDrinks;
    }

    var nextAt = nextRefillAt;
    var now = DateTime.now();
    while (count < maxDrinks && nextAt != null && !now.isBefore(nextAt)) {
      count++;
      if (count < maxDrinks) {
        nextAt = nextAt.add(refillDuration);
      } else {
        nextAt = null;
      }
    }
    onNextRefillUpdated(nextAt);
    return count;
  }

  static Future<void> _save({
    required int count,
    required DateTime? nextRefillAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCount, count.clamp(0, maxDrinks));
    if (nextRefillAt == null) {
      await prefs.remove(_keyNextRefillMs);
    } else {
      await prefs.setInt(
        _keyNextRefillMs,
        nextRefillAt.millisecondsSinceEpoch,
      );
    }
  }
}
