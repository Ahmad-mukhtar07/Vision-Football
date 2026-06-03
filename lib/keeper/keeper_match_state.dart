import 'dart:math';

import 'package:flutter/foundation.dart';

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
  });

  final int totalShots;
  final int shotsTaken;
  final int saves;
  final int goalsConceded;
  final KeeperPhase phase;
  final KeeperShotResult? lastResult;
  final KeeperSpotType spotType;

  KeeperMatchState copyWith({
    int? totalShots,
    int? shotsTaken,
    int? saves,
    int? goalsConceded,
    KeeperPhase? phase,
    KeeperShotResult? lastResult,
    KeeperSpotType? spotType,
    bool clearLastResult = false,
  }) {
    return KeeperMatchState(
      totalShots: totalShots ?? this.totalShots,
      shotsTaken: shotsTaken ?? this.shotsTaken,
      saves: saves ?? this.saves,
      goalsConceded: goalsConceded ?? this.goalsConceded,
      phase: phase ?? this.phase,
      lastResult: clearLastResult ? null : (lastResult ?? this.lastResult),
      spotType: spotType ?? this.spotType,
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

  void startMatch() {
    _state = const KeeperMatchState(phase: KeeperPhase.calibrating);
    notifyListeners();
  }

  /// Transition out of calibration into the first round.
  void finishCalibration() {
    if (_state.phase != KeeperPhase.calibrating) return;
    _state = _state.copyWith(phase: KeeperPhase.waitingForReady);
    notifyListeners();
  }

  void restart() => startMatch();

  /// Picks penalty or free kick for the upcoming round.
  void assignRandomSpot() {
    final spot = _random.nextBool()
        ? KeeperSpotType.penalty
        : KeeperSpotType.freeKick;
    _state = _state.copyWith(spotType: spot);
    notifyListeners();
  }

  void onShotLaunched() {
    if (_state.phase != KeeperPhase.waitingForReady) return;
    _state = _state.copyWith(phase: KeeperPhase.shotIncoming);
    notifyListeners();
  }

  void onShotResolved(KeeperShotResult result) {
    if (_state.phase != KeeperPhase.shotIncoming) return;
    final taken = _state.shotsTaken + 1;
    final saves = _state.saves + (result == KeeperShotResult.saved ? 1 : 0);
    final goals = _state.goalsConceded +
        (result == KeeperShotResult.conceded ? 1 : 0);
    _state = _state.copyWith(
      shotsTaken: taken,
      saves: saves,
      goalsConceded: goals,
      lastResult: result,
      phase: KeeperPhase.resultPause,
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
