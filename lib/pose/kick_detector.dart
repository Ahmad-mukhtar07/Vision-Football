import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kick_event.dart';
import '../models/kicking_foot.dart';
import 'kick_detection_config.dart';
import 'pose_detector_service.dart';

enum KickPhase {
  idle,
  strike,
  cooldown,
}

class _FootFrame {
  _FootFrame({
    required this.positionNormalized,
    required this.z,
    required this.confidence,
    required this.timestamp,
  });

  final Offset positionNormalized;
  final double z;
  final double confidence;
  final DateTime timestamp;
}

/// Detects kicks via Z-depth thrust toward camera + planted-foot check.
class KickDetector {
  KickDetector({
    required Stream<List<PoseLandmark>> poseStream,
    KickDetectionConfig config = KickDetectionConfig.defaults,
  })  : _config = config,
        _poseStream = poseStream {
    _subscription = _poseStream.listen(_onPoseFrame);
  }

  final Stream<List<PoseLandmark>> _poseStream;
  final KickDetectionConfig _config;

  final StreamController<KickEvent> _kickController =
      StreamController<KickEvent>.broadcast();

  Stream<KickEvent> get kickStream => _kickController.stream;

  final StreamController<KickCooldownUpdate> _cooldownUiController =
      StreamController<KickCooldownUpdate>.broadcast();

  /// On-screen cooldown countdown (see [KickCooldownBanner]).
  Stream<KickCooldownUpdate> get cooldownUpdates => _cooldownUiController.stream;

  StreamSubscription<List<PoseLandmark>>? _subscription;
  Timer? _cooldownTimer;
  Timer? _cooldownUiTimer;

  KickPhase _phase = KickPhase.idle;
  KickPhase get phase => _phase;

  bool _detectionArmed = false;
  bool _gameCanAcceptKick = true;
  bool _mirrorPreviewAim = false;

  bool? _lockedIsLeft;
  KickingFoot? get kickingFoot => _lockedIsLeft == null
      ? null
      : (_lockedIsLeft! ? KickingFoot.left : KickingFoot.right);

  Offset? _neutralPosition;
  Size? _imageSize;

  final Queue<_FootFrame> _buffer = Queue<_FootFrame>();
  static const int _bufferSize = 3;

  Offset? _lastAcceptedPosition;
  DateTime? _cooldownEndsAt;

  DateTime? _lastRunupLogTime;
  DateTime? _lastTeleportLogTime;
  DateTime? _lastNearKickLogTime;
  bool _loggedCooldownStart = false;
  static const Duration _runupLogCooldown = Duration(milliseconds: 800);
  static const Duration _teleportLogCooldown = Duration(seconds: 4);
  static const Duration _nearKickLogCooldown = Duration(seconds: 2);

  final Map<bool, Offset> _lastPlantedPositions = {};

  final StreamController<bool> _playerIsStillController =
      StreamController<bool>.broadcast();

  /// True when both ankles moved less than [KickDetectionConfig.plantedFootMaxMove]
  /// for 4 consecutive frames (same pose frames as kick detection).
  Stream<bool> get playerIsStill => _playerIsStillController.stream;

  static const int _stillFramesRequired = 4;
  Offset? _stillPrevLeft;
  Offset? _stillPrevRight;
  int _consecutiveBothStillFrames = 0;
  bool _lastEmittedStill = false;

  void updateImageSize(Size size) {
    _imageSize = size;
  }

  void setKickingFoot(KickingFoot foot) {
    _lockedIsLeft = foot.isLeft;
    _resetTrackingState();
    disableKicks();
  }

  void setMirrorPreviewAim(bool value) {
    _mirrorPreviewAim = value;
  }

  void clearKickingFoot() {
    _lockedIsLeft = null;
    _resetTrackingState();
    disableKicks();
  }

  void applyCalibration(Offset neutralPosition) {
    _neutralPosition = neutralPosition;
    _detectionArmed = false;
    _resetTrackingState();
    _phase = KickPhase.idle;
    _cooldownTimer?.cancel();
  }

  /// Arms kick detection (requires foot + calibration already applied).
  void arm() => enableKickDetection();

  /// Disarms detection but keeps foot lock and neutral stance.
  void disarm() {
    _detectionArmed = false;
    _phase = KickPhase.idle;
    _cooldownTimer?.cancel();
    _cooldownUiTimer?.cancel();
    _cooldownEndsAt = null;
    _emitCooldownUi(inactive: true);
    _resetTrackingState();
  }

  void enableKickDetection() {
    if (_lockedIsLeft == null || _neutralPosition == null) return;
    _detectionArmed = true;
    _resetTrackingState();
    _phase = KickPhase.idle;
    _cooldownTimer?.cancel();
    debugPrint('[KD] >>> READY — kick detection armed <<<');
  }

  void disableKicks() {
    _detectionArmed = false;
    _neutralPosition = null;
    _resetTrackingState();
    _phase = KickPhase.idle;
    _cooldownTimer?.cancel();
    _cooldownUiTimer?.cancel();
    _cooldownEndsAt = null;
    _emitCooldownUi(inactive: true);
  }

  void setGameCanAcceptKick(bool value) {
    if (value && _phase == KickPhase.cooldown) return;
    _gameCanAcceptKick = value;
  }

  void _resetTrackingState() {
    _buffer.clear();
    _lastAcceptedPosition = null;
    _lastPlantedPositions.clear();
    _stillPrevLeft = null;
    _stillPrevRight = null;
    _consecutiveBothStillFrames = 0;
  }

  void _onPoseFrame(List<PoseLandmark> landmarks) {
    if (_lockedIsLeft == null) return;

    final imageSize = _imageSize;
    if (imageSize == null) return;

    _updatePlayerStillness(landmarks, imageSize);

    if (!_detectionArmed) return;

    if (_phase == KickPhase.cooldown) {
      return;
    }

    if (!_gameCanAcceptKick) {
      return;
    }

    final kicking = _sampleKickingAnkle(landmarks, imageSize);
    if (kicking == null) {
      return;
    }

    if (_isTeleport(kicking.position, kicking.confidence)) {
      _logTeleport(_teleportDelta(kicking.position));
      return;
    }

    _lastAcceptedPosition = kicking.position;

    _buffer.addLast(
      _FootFrame(
        positionNormalized: kicking.position,
        z: kicking.z,
        confidence: kicking.confidence,
        timestamp: DateTime.now(),
      ),
    );
    while (_buffer.length > _bufferSize) {
      _buffer.removeFirst();
    }

    final metrics = _evaluateKick(landmarks, imageSize);
    _logIdleOrNearKick(metrics, kicking.confidence);

    if (metrics.runupRejected) {
      _logRunupStep(metrics.plantMove);
    }

    if (metrics.isKick) {
      _emitStrike(metrics);
    }
  }

  ({Offset position, double z, double confidence})? _sampleKickingAnkle(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    final locked = _lockedIsLeft;
    if (locked == null) return null;

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = locked
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];

    if (ankle == null || ankle.likelihood < _config.minConfidence) {
      return null;
    }

    return (
      position: Offset(
        ankle.x / imageSize.width,
        ankle.y / imageSize.height,
      ),
      z: ankle.z,
      confidence: ankle.likelihood,
    );
  }

  ({Offset position, double confidence})? _samplePlantedAnkle(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    final plantedIsLeft = !_lockedIsLeft!;
    final byType = {for (final l in landmarks) l.type: l};
    final ankle = plantedIsLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];

    if (ankle == null || ankle.likelihood < _config.minConfidence) {
      return null;
    }

    return (
      position: Offset(
        ankle.x / imageSize.width,
        ankle.y / imageSize.height,
      ),
      confidence: ankle.likelihood,
    );
  }

  double _teleportDelta(Offset position) {
    final last = _lastAcceptedPosition;
    if (last == null) return 0;
    return (position - last).distance;
  }

  bool _isTeleport(Offset position, double confidence) {
    final delta = _teleportDelta(position);
    if (delta <= _config.maxPlausibleMovement) return false;
    // Fast, confident motion is a real kick — do not freeze tracking.
    if (confidence >= 0.72 && delta < _config.maxKickMotionPerFrame) {
      return false;
    }
    return true;
  }

  _KickMetrics _evaluateKick(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    if (_buffer.length < 2) {
      return _KickMetrics.idle;
    }

    final frames = _buffer.toList();
    final prev = frames[frames.length - 2];
    final curr = frames[frames.length - 1];

    if (prev.confidence < _config.minConfidence ||
        curr.confidence < _config.minConfidence) {
      return _KickMetrics.emptyAt(curr);
    }

    final xyDelta = curr.positionNormalized - prev.positionNormalized;
    final xySpeed = xyDelta.distance;
    final zDelta = curr.z - prev.z;

    final plantedIsLeft = !_lockedIsLeft!;
    final planted = _samplePlantedAnkle(landmarks, imageSize);
    var plantMove = double.infinity;
    if (planted != null) {
      final prevPlanted = _lastPlantedPositions[plantedIsLeft];
      if (prevPlanted != null) {
        plantMove = (planted.position - prevPlanted).distance;
      } else {
        plantMove = 0;
      }
      _lastPlantedPositions[plantedIsLeft] = planted.position;
    }

    final zScale = _zScale(prev.z, curr.z);
    final zThrust = _isZThrust(zDelta, zScale) &&
        (_buffer.length < 3 ||
            _isZThrust(prev.z - frames[frames.length - 3].z, zScale));

    final speedOk = xySpeed >= _config.strikeSpeedThreshold;
    final plantOk = plantMove <= _config.plantedFootMaxMove;

    // Rule 4 (planted foot) is what distinguishes kick from run-up steps.
    // During a run-up, both ankles move. At strike, the standing foot stops.
    // This means run-up can flow directly into a kick naturally — no gate needed.
    final runupRejected = zThrust && speedOk && !plantOk;
    final isKick = zThrust && speedOk && plantOk;
    final zThrustCandidate = _isZThrust(zDelta, zScale);

    final windowStart = frames.first.positionNormalized;
    final windowEnd = curr.positionNormalized;
    final windowDelta = windowEnd - windowStart;
    final sensorDegrees =
        PoseDetectorService.instance.sensorRotationDegrees ?? 0;

    final aimDelta = _lateralAimDelta(windowDelta, xyDelta, sensorDegrees);
    final normalizedAim = Offset(
      (aimDelta.dx / _config.aimReferenceDelta).clamp(-1.5, 1.5),
      aimDelta.dy,
    );

    return _KickMetrics(
      xySpeed: xySpeed,
      zDelta: zDelta,
      plantMove: plantMove.isFinite ? plantMove : 999,
      isKick: isKick,
      runupRejected: runupRejected,
      rawDelta: xyDelta,
      correctedDelta: normalizedAim,
      footPosition: curr.positionNormalized,
      type: _classifyType(curr.positionNormalized.dy),
      sensorDegrees: sensorDegrees,
      zThrustCandidate: zThrustCandidate,
    );
  }

  /// Lateral aim: prefer sensor-corrected delta; fall back to dominant image axis.
  Offset _lateralAimDelta(
    Offset windowDelta,
    Offset instantDelta,
    int sensorDegrees,
  ) {
    final correctedInstant = _correctDeltaForSensor(instantDelta, sensorDegrees);
    final correctedWindow = _correctDeltaForSensor(windowDelta, sensorDegrees);

    var lateral = correctedWindow.dx.abs() >= correctedInstant.dx.abs()
        ? correctedWindow.dx
        : correctedInstant.dx;

    if (lateral.abs() < 0.006) {
      final raw = windowDelta.dx.abs() >= windowDelta.dy.abs()
          ? windowDelta.dx
          : -windowDelta.dy;
      lateral = raw;
    }

    return Offset(lateral, correctedInstant.dy);
  }

  Offset _correctDeltaForSensor(Offset rawDelta, int sensorDegrees) {
    switch (sensorDegrees) {
      case 90:
        return Offset(rawDelta.dy, -rawDelta.dx);
      case 270:
        return Offset(-rawDelta.dy, rawDelta.dx);
      case 180:
        return Offset(-rawDelta.dx, -rawDelta.dy);
      case 0:
      default:
        return rawDelta;
    }
  }

  KickType _classifyType(double footY) {
    return footY < _config.aerialYThreshold ? KickType.aerial : KickType.ground;
  }

  void _emitStrike(_KickMetrics metrics) {
    _phase = KickPhase.strike;

    final event = KickEvent(
      footPositionNormalized: metrics.footPosition,
      strikeDeltaNormalized: metrics.correctedDelta,
      strikeSpeed: metrics.xySpeed,
      type: metrics.type,
      timestamp: DateTime.now(),
      mirrorPreviewAim: _mirrorPreviewAim,
    );

    debugPrint('');
    debugPrint('[KD] ══════ KICK DETECTED ══════');
    debugPrint(
      '[KD] STRIKE  speed=${metrics.xySpeed.toStringAsFixed(3)} '
      'zDelta=${metrics.zDelta.toStringAsFixed(2)} '
      'aim=(${metrics.correctedDelta.dx.toStringAsFixed(2)}, '
      '${metrics.correctedDelta.dy.toStringAsFixed(2)}) '
      'sensor=${metrics.sensorDegrees}  type=${metrics.type.name}',
    );
    debugPrint('[KD] ══════════════════════════');
    debugPrint('');

    _kickController.add(event);
    _enterCooldown();
  }

  void _enterCooldown() {
    _phase = KickPhase.cooldown;
    _buffer.clear();
    _lastAcceptedPosition = null;
    _lastPlantedPositions.clear();
    _cooldownEndsAt = DateTime.now().add(_config.cooldownDuration);
    _cooldownTimer?.cancel();
    _loggedCooldownStart = false;
    _emitCooldownUi(inactive: false);
    _cooldownUiTimer?.cancel();
    _cooldownUiTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _emitCooldownUi(inactive: false);
    });
    _cooldownTimer = Timer(_config.cooldownDuration, () {
      _phase = KickPhase.idle;
      _cooldownEndsAt = null;
      _cooldownUiTimer?.cancel();
      _emitCooldownUi(inactive: true);
    });
    _logCooldownStart();
  }

  double _zScale(double prevZ, double currZ) {
    return (prevZ.abs() + currZ.abs()) * 0.5 + 80.0;
  }

  bool _isZThrust(double zDelta, double zScale) {
    return zDelta < -_config.minZThrustPixels &&
        zDelta / zScale < -_config.minZThrustRelative;
  }

  void _emitCooldownUi({required bool inactive}) {
    if (inactive || _cooldownEndsAt == null) {
      _cooldownUiController.add(KickCooldownUpdate.inactive);
      return;
    }
    final remainingMs = _cooldownEndsAt!
        .difference(DateTime.now())
        .inMilliseconds
        .clamp(0, _config.cooldownDuration.inMilliseconds);
    _cooldownUiController.add(
      KickCooldownUpdate(
        active: true,
        remainingMs: remainingMs,
        totalMs: _config.cooldownDuration.inMilliseconds,
      ),
    );
  }

  void _logIdleOrNearKick(_KickMetrics metrics, double conf) {
    if (KickDetectionConfig.verboseFrameLogs) {
      debugPrint(
        '[KD] IDLE buf=${_buffer.length} xySpeed=${metrics.xySpeed.toStringAsFixed(3)} '
        'zDelta=${metrics.zDelta.toStringAsFixed(2)} '
        'plantMove=${metrics.plantMove.toStringAsFixed(3)} conf=${conf.toStringAsFixed(2)}',
      );
      return;
    }

    final nearKick = metrics.zThrustCandidate &&
        metrics.xySpeed >= _config.strikeSpeedThreshold * 0.7;
    if (!nearKick) return;

    final now = DateTime.now();
    if (_lastNearKickLogTime != null &&
        now.difference(_lastNearKickLogTime!) < _nearKickLogCooldown) {
      return;
    }
    _lastNearKickLogTime = now;
    debugPrint(
      '[KD] (near) zDelta=${metrics.zDelta.toStringAsFixed(2)} '
      'speed=${metrics.xySpeed.toStringAsFixed(3)} plant=${metrics.plantMove.toStringAsFixed(3)}',
    );
  }

  void _logTeleport(double delta) {
    final now = DateTime.now();
    if (_lastTeleportLogTime != null &&
        now.difference(_lastTeleportLogTime!) < _teleportLogCooldown) {
      return;
    }
    _lastTeleportLogTime = now;
    debugPrint('[KD] TELEPORT discarded xyDelta=${delta.toStringAsFixed(2)}');
  }

  void _logRunupStep(double plantMove) {
    if (!KickDetectionConfig.logRunupSteps) return;
    final now = DateTime.now();
    if (_lastRunupLogTime != null &&
        now.difference(_lastRunupLogTime!) < _runupLogCooldown) {
      return;
    }
    _lastRunupLogTime = now;
    debugPrint(
      '[KD] RUNUP_STEP plant=${plantMove.toStringAsFixed(3)} '
      '(max ${_config.plantedFootMaxMove.toStringAsFixed(3)})',
    );
  }

  void _logCooldownStart() {
    if (_loggedCooldownStart) return;
    _loggedCooldownStart = true;
    final ms = _config.cooldownDuration.inMilliseconds;
    debugPrint('[KD] cooldown ${ms}ms (next kick after)');
  }

  void _updatePlayerStillness(List<PoseLandmark> landmarks, Size imageSize) {
    final left = _ankleNorm(landmarks, imageSize, isLeft: true);
    final right = _ankleNorm(landmarks, imageSize, isLeft: false);
    if (left == null || right == null) {
      _consecutiveBothStillFrames = 0;
      _emitPlayerStill(false);
      return;
    }

    if (_stillPrevLeft == null || _stillPrevRight == null) {
      _stillPrevLeft = left;
      _stillPrevRight = right;
      _consecutiveBothStillFrames = 0;
      _emitPlayerStill(false);
      return;
    }

    final leftMove = (left - _stillPrevLeft!).distance;
    final rightMove = (right - _stillPrevRight!).distance;
    _stillPrevLeft = left;
    _stillPrevRight = right;

    final maxMove = _config.plantedFootMaxMove;
    if (leftMove <= maxMove && rightMove <= maxMove) {
      _consecutiveBothStillFrames++;
    } else {
      _consecutiveBothStillFrames = 0;
    }

    final isStill = _consecutiveBothStillFrames >= _stillFramesRequired;
    _emitPlayerStill(isStill);
  }

  void _emitPlayerStill(bool isStill) {
    if (isStill == _lastEmittedStill) return;
    _lastEmittedStill = isStill;
    if (!_playerIsStillController.isClosed) {
      _playerIsStillController.add(isStill);
    }
  }

  Offset? _ankleNorm(
    List<PoseLandmark> landmarks,
    Size imageSize, {
    required bool isLeft,
  }) {
    final byType = {for (final l in landmarks) l.type: l};
    final ankle = isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    if (ankle == null || ankle.likelihood < _config.minConfidence * 0.9) {
      return null;
    }
    return Offset(
      ankle.x / imageSize.width,
      ankle.y / imageSize.height,
    );
  }

  void dispose() {
    _cooldownTimer?.cancel();
    _cooldownUiTimer?.cancel();
    _subscription?.cancel();
    _kickController.close();
    _cooldownUiController.close();
    _playerIsStillController.close();
  }
}

/// UI state for [KickCooldownBanner].
class KickCooldownUpdate {
  const KickCooldownUpdate({
    required this.active,
    required this.remainingMs,
    required this.totalMs,
  });

  static const KickCooldownUpdate inactive = KickCooldownUpdate(
    active: false,
    remainingMs: 0,
    totalMs: 0,
  );

  final bool active;
  final int remainingMs;
  final int totalMs;
}

class _KickMetrics {
  const _KickMetrics({
    required this.xySpeed,
    required this.zDelta,
    required this.plantMove,
    required this.isKick,
    required this.runupRejected,
    required this.rawDelta,
    required this.correctedDelta,
    required this.footPosition,
    required this.type,
    required this.sensorDegrees,
    required this.zThrustCandidate,
  });

  static const _KickMetrics idle = _KickMetrics(
    xySpeed: 0,
    zDelta: 0,
    plantMove: 0,
    isKick: false,
    runupRejected: false,
    rawDelta: Offset.zero,
    correctedDelta: Offset.zero,
    footPosition: Offset.zero,
    type: KickType.ground,
    sensorDegrees: 0,
    zThrustCandidate: false,
  );

  static _KickMetrics emptyAt(_FootFrame curr) => _KickMetrics(
        xySpeed: 0,
        zDelta: 0,
        plantMove: 0,
        isKick: false,
        runupRejected: false,
        rawDelta: Offset.zero,
        correctedDelta: Offset.zero,
        footPosition: curr.positionNormalized,
        type: KickType.ground,
        sensorDegrees: 0,
        zThrustCandidate: false,
      );

  final double xySpeed;
  final double zDelta;
  final double plantMove;
  final bool isKick;
  final bool runupRejected;
  final Offset rawDelta;
  final Offset correctedDelta;
  final Offset footPosition;
  final KickType type;
  final int sensorDegrees;
  final bool zThrustCandidate;
}
