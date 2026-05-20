import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kick_event.dart';

/// Kick detection state machine: IDLE → WINDUP → STRIKE → COOLDOWN → IDLE.
enum KickPhase {
  idle,
  windup,
  strike,
  cooldown,
}

enum _TrackedFoot {
  left,
  right,
}

class _FootFrame {
  _FootFrame({
    required this.position,
    required this.confidence,
    required this.timestamp,
  });

  final Offset position;
  final double confidence;
  final DateTime timestamp;
}

/// Detects real kicks from a stream of pose landmarks using normalized coordinates.
class KickDetector {
  KickDetector({
    required Stream<List<PoseLandmark>> poseStream,
    this.windupSpeedThreshold = 0.008,
    this.strikeSpeedThreshold = 0.02,
    this.maxPlausibleMovement = 0.15,
    this.cooldownDuration = const Duration(milliseconds: 800),
    this.minConfidence = 0.6,
    this.windupTimeLimit = const Duration(milliseconds: 600),
  }) : _poseStream = poseStream {
    _subscription = _poseStream.listen(_onPoseFrame);
  }

  final Stream<List<PoseLandmark>> _poseStream;

  final double windupSpeedThreshold;
  final double strikeSpeedThreshold;
  final double maxPlausibleMovement;
  final Duration cooldownDuration;
  final double minConfidence;
  final Duration windupTimeLimit;

  final StreamController<KickEvent> _kickController =
      StreamController<KickEvent>.broadcast();

  Stream<KickEvent> get kickStream => _kickController.stream;

  StreamSubscription<List<PoseLandmark>>? _subscription;
  Timer? _cooldownTimer;

  KickPhase _phase = KickPhase.idle;
  KickPhase get phase => _phase;

  Size? _imageSize;
  final Queue<_FootFrame> _history = Queue<_FootFrame>();

  _TrackedFoot? _activeFoot;
  DateTime? _windupEnteredAt;
  Offset? _lastTrackedPosition;
  DateTime? _lastTrackedAt;

  /// +1 = wind-up moves foot down (Y↑), -1 = wind-up moves foot up (Y↓).
  int? _windupDySign;

  DateTime? _lastTeleportLogTime;
  static const Duration _teleportLogCooldown = Duration(seconds: 5);

  static const int _maxHistorySize = 5;
  static const int _windupConsecutiveFrames = 3;
  static const double _trackingLostConfidence = 0.5;
  static const double _aerialYThreshold = 0.45;
  static const double _chipHorizontalRatio = 0.6;
  static const double _referenceFrameMs = 33.0;
  static const double _maxMovementScaleCap = 4.0;

  /// Supplies image dimensions for landmark normalization (from [PoseDetectorService]).
  void updateImageSize(Size size) {
    _imageSize = size;
  }

  void _onPoseFrame(List<PoseLandmark> landmarks) {
    if (_phase == KickPhase.cooldown) return;

    final imageSize = _imageSize;
    if (imageSize == null) return;

    final sample = _sampleTrackedFoot(landmarks, imageSize);
    if (sample == null) {
      _handleMissingLandmarks();
      return;
    }

    final frame = _FootFrame(
      position: sample.position,
      confidence: sample.confidence,
      timestamp: DateTime.now(),
    );

    if (_checkTeleport(frame)) return;

    _pushHistory(frame);
    _lastTrackedPosition = frame.position;
    _lastTrackedAt = frame.timestamp;

    switch (_phase) {
      case KickPhase.idle:
        _processIdle(frame, sample.foot);
      case KickPhase.windup:
        _processWindup(frame);
      case KickPhase.strike:
      case KickPhase.cooldown:
        break;
    }
  }

  void _handleMissingLandmarks() {
    if (_phase == KickPhase.windup) {
      _resetToIdle();
    }
  }

  /// Scales allowed jump by time between pose frames (pose runs ~6–10 Hz, not 30).
  bool _checkTeleport(_FootFrame frame) {
    final previous = _lastTrackedPosition;
    final previousAt = _lastTrackedAt;
    if (previous == null || previousAt == null) return false;

    final distance = (frame.position - previous).distance;
    final elapsedMs = frame.timestamp.difference(previousAt).inMilliseconds;
    final scale =
        (elapsedMs / _referenceFrameMs).clamp(1.0, _maxMovementScaleCap);
    final allowance = maxPlausibleMovement * scale;

    if (distance <= allowance) return false;

    final now = DateTime.now();
    if (_lastTeleportLogTime == null ||
        now.difference(_lastTeleportLogTime!) >= _teleportLogCooldown) {
      _lastTeleportLogTime = now;
      debugPrint(
        '[KICK] Teleport discarded — distance: ${distance.toStringAsFixed(3)} '
        '(allowance: ${allowance.toStringAsFixed(3)}, ${elapsedMs}ms gap)',
      );
    }
    _resetToIdle(clearLastPosition: true);
    return true;
  }

  void _processIdle(_FootFrame frame, _TrackedFoot foot) {
    _activeFoot = foot;
    final sign = _detectConsecutiveMotionSign(_windupConsecutiveFrames);
    if (sign == null) return;

    _windupDySign = sign;
    _phase = KickPhase.windup;
    _windupEnteredAt = frame.timestamp;
    debugPrint('[KICK] Wind-up detected (foot ${foot.name})');
  }

  void _processWindup(_FootFrame frame) {
    if (_windupEnteredAt != null &&
        frame.timestamp.difference(_windupEnteredAt!) > windupTimeLimit) {
      _resetToIdle();
      return;
    }

    if (frame.confidence < _trackingLostConfidence) {
      _resetToIdle();
      return;
    }

    if (_hasStrike(frame)) {
      _emitStrike(frame);
      _enterCooldown();
    }
  }

  /// Returns +1 if Y increased for [count] steps, -1 if Y decreased, else null.
  int? _detectConsecutiveMotionSign(int count) {
    if (_history.length < count + 1) return null;

    final frames = _history.toList();
    int? sign;

    for (var i = frames.length - count; i < frames.length; i++) {
      final previous = frames[i - 1];
      final current = frames[i];
      final delta = current.position - previous.position;
      final speed = delta.distance;

      if (speed < windupSpeedThreshold || current.confidence < minConfidence) {
        return null;
      }
      if (delta.dy == 0) return null;

      final stepSign = delta.dy > 0 ? 1 : -1;
      sign ??= stepSign;
      if (stepSign != sign) return null;
    }
    return sign;
  }

  bool _hasStrike(_FootFrame frame) {
    if (_history.length < 2 || _windupDySign == null) return false;

    final previous = _history.elementAt(_history.length - 2);
    final delta = frame.position - previous.position;
    final speed = delta.distance;
    if (speed < strikeSpeedThreshold) return false;

    final strikeSign = delta.dy > 0 ? 1 : (delta.dy < 0 ? -1 : 0);
    return strikeSign == -_windupDySign!;
  }

  void _emitStrike(_FootFrame frame) {
    final previous = _history.length >= 2
        ? _history.elementAt(_history.length - 2)
        : null;
    final delta = previous != null
        ? frame.position - previous.position
        : Offset.zero;
    final strikeSpeed = delta.distance;

    final event = KickEvent(
      footPositionNormalized: frame.position,
      strikeSpeed: strikeSpeed,
      type: _classifyKick(frame.position, delta),
      timestamp: frame.timestamp,
    );

    _kickController.add(event);
  }

  KickType _classifyKick(Offset position, Offset delta) {
    final footHigh = position.dy < _aerialYThreshold;
    if (!footHigh) return KickType.ground;

    final horizontalSpeed = delta.dx.abs();
    final verticalSpeed = delta.dy.abs();
    if (verticalSpeed > 0 &&
        horizontalSpeed < verticalSpeed * _chipHorizontalRatio) {
      return KickType.chip;
    }
    return KickType.aerial;
  }

  void _enterCooldown() {
    _phase = KickPhase.cooldown;
    _history.clear();
    _lastTrackedPosition = null;
    _lastTrackedAt = null;
    _activeFoot = null;
    _windupEnteredAt = null;
    _windupDySign = null;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldownDuration, () {
      _resetToIdle(clearLastPosition: true);
    });
  }

  void _resetToIdle({bool clearLastPosition = false}) {
    _phase = KickPhase.idle;
    _activeFoot = null;
    _windupEnteredAt = null;
    _windupDySign = null;
    _history.clear();
    if (clearLastPosition) {
      _lastTrackedPosition = null;
      _lastTrackedAt = null;
    }
  }

  void _pushHistory(_FootFrame frame) {
    _history.addLast(frame);
    while (_history.length > _maxHistorySize) {
      _history.removeFirst();
    }
  }

  ({Offset position, double confidence, _TrackedFoot foot})? _sampleTrackedFoot(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    final byType = {for (final l in landmarks) l.type: l};
    final left = byType[PoseLandmarkType.leftAnkle];
    final right = byType[PoseLandmarkType.rightAnkle];

    if (_phase == KickPhase.windup && _activeFoot != null) {
      final tracked = _activeFoot == _TrackedFoot.left ? left : right;
      if (tracked == null) return null;
      return (
        position: _normalize(tracked, imageSize),
        confidence: tracked.likelihood,
        foot: _activeFoot!,
      );
    }

    if (left == null && right == null) return null;

    final PoseLandmark chosen;
    final _TrackedFoot foot;
    if (left == null) {
      chosen = right!;
      foot = _TrackedFoot.right;
    } else if (right == null) {
      chosen = left;
      foot = _TrackedFoot.left;
    } else if (left.likelihood >= right.likelihood) {
      chosen = left;
      foot = _TrackedFoot.left;
    } else {
      chosen = right;
      foot = _TrackedFoot.right;
    }

    if (chosen.likelihood < minConfidence) return null;

    return (
      position: _normalize(chosen, imageSize),
      confidence: chosen.likelihood,
      foot: foot,
    );
  }

  Offset _normalize(PoseLandmark landmark, Size imageSize) {
    return Offset(
      landmark.x / imageSize.width,
      landmark.y / imageSize.height,
    );
  }

  void dispose() {
    _cooldownTimer?.cancel();
    _subscription?.cancel();
    _kickController.close();
  }
}
