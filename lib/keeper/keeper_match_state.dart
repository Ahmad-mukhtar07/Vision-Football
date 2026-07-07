import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/game_settings.dart';
import '../game/shot_type_schedule.dart';
import '../ui/penalty_score_bar.dart';
import 'keeper_layout_constants.dart';

/// Outcome of a single keeper round.
enum KeeperShotResult { saved, conceded }

/// Lifecycle of the goalkeeper match.
enum KeeperPhase {
  notStarted,
  calibrating,
  waitingForReady,
  shotIncoming,
  resultPause,
  matchOver,
}

/// Immutable snapshot of keeper match progress.
@immutable
class KeeperMatchState {
  const KeeperMatchState({
    this.totalShots = 5,
    this.shotsTaken = 0,
    this.saves = 0,
    this.goalsConceded = 0,
    this.phase = KeeperPhase.notStarted,
    this.lastResult,
    this.spotType = KeeperSpotType.penalty,
    this.penaltySpots = const [],
    this.goalScorers = const [],
  });

  final int totalShots;
  final int shotsTaken;
  final int saves;
  final int goalsConceded;
  final KeeperPhase phase;
  final KeeperShotResult? lastResult;
  final KeeperSpotType spotType;
  final List<PenaltySpotStatus> penaltySpots;

  /// Names of opposing shooters who scored, in shot order.
  final List<String> goalScorers;

  KeeperMatchState copyWith({
    int? totalShots,
    int? shotsTaken,
    int? saves,
    int? goalsConceded,
    KeeperPhase? phase,
    KeeperShotResult? lastResult,
    KeeperSpotType? spotType,
    bool clearLastResult = false,
    List<PenaltySpotStatus>? penaltySpots,
    List<String>? goalScorers,
  }) {
    return KeeperMatchState(
      totalShots: totalShots ?? this.totalShots,
      shotsTaken: shotsTaken ?? this.shotsTaken,
      saves: saves ?? this.saves,
      goalsConceded: goalsConceded ?? this.goalsConceded,
      phase: phase ?? this.phase,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      spotType: spotType ?? this.spotType,
      penaltySpots: penaltySpots ?? this.penaltySpots,
      goalScorers: goalScorers ?? this.goalScorers,
    );
  }
}

/// Owns keeper match lifecycle (round counter, save/goal tally, phases).
///
/// Entirely independent of the shooting-mode `MatchController` — no shared
/// state, no shared phase enums, no shared restart logic.
class KeeperMatchController extends ChangeNotifier {
  KeeperMatchState _state = const KeeperMatchState();
  KeeperMatchState get state => _state;
  final Random _random = Random();

  /// Pre-generated spot sequence for the current match (index = shotsTaken).
  List<KeeperSpotType> _spotSchedule = [];

  void startMatch() {
    const totalShots = 5;
    _spotSchedule = ShotTypeSchedule.forKeeping(
      mode: GameSettings.difficulty,
      totalKicks: totalShots,
      random: _random,
    );
    _state = KeeperMatchState(
      totalShots: totalShots,
      phase: KeeperPhase.calibrating,
      penaltySpots: PenaltyScoreBar.initialSpots(totalShots),
    );
    notifyListeners();
  }

  /// Transition out of calibration into the first round.
  void finishCalibration() {
    if (_state.phase != KeeperPhase.calibrating) return;
    _state = _state.copyWith(phase: KeeperPhase.waitingForReady);
    notifyListeners();
  }

  void restart() => startMatch();

  /// Assigns penalty or free kick for the upcoming round from the pre-built
  /// schedule (first shot is always a penalty).
  void assignRandomSpot() {
    final idx = _state.shotsTaken.clamp(0, _spotSchedule.length - 1);
    final spot = _spotSchedule.isNotEmpty
        ? _spotSchedule[idx]
        : KeeperSpotType.penalty;
    _state = _state.copyWith(spotType: spot);
    notifyListeners();
  }

  void onShotLaunched() {
    if (_state.phase != KeeperPhase.waitingForReady) return;
    _state = _state.copyWith(phase: KeeperPhase.shotIncoming);
    notifyListeners();
  }

  void onShotResolved(KeeperShotResult result, {String? goalScorer}) {
    if (_state.phase != KeeperPhase.shotIncoming) return;
    final taken = _state.shotsTaken + 1;
    final saves = _state.saves + (result == KeeperShotResult.saved ? 1 : 0);
    final goals = _state.goalsConceded +
        (result == KeeperShotResult.conceded ? 1 : 0);
    var scorers = List<String>.from(_state.goalScorers);
    if (result == KeeperShotResult.conceded &&
        goalScorer != null &&
        goalScorer.isNotEmpty) {
      scorers.add(goalScorer);
    }
    final spots = List<PenaltySpotStatus>.from(_state.penaltySpots);
    spots[taken - 1] = result == KeeperShotResult.conceded
        ? PenaltySpotStatus.scored
        : PenaltySpotStatus.missed;

    _state = _state.copyWith(
      shotsTaken: taken,
      saves: saves,
      goalsConceded: goals,
      goalScorers: scorers,
      lastResult: result,
      phase: KeeperPhase.resultPause,
      penaltySpots: spots,
    );
    notifyListeners();
  }

  /// After the result pause, advance to the next round or full time.
  void readyForNextShot() {
    if (_state.phase != KeeperPhase.resultPause) return;
    if (_state.shotsTaken >= _state.totalShots) {
      _state = _state.copyWith(phase: KeeperPhase.matchOver);
    } else {
      _state = _state.copyWith(
        phase: KeeperPhase.waitingForReady,
        clearLastResult: true,
      );
    }
    notifyListeners();
  }

  void abandon() {
    _state = const KeeperMatchState(phase: KeeperPhase.notStarted);
    notifyListeners();
  }
}
