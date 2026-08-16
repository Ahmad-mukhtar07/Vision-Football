import 'dart:async';
import 'dart:collection';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../game/game_foot_marker_controller.dart';
import '../models/kick_event.dart';
import '../models/kicking_foot.dart';
import 'kick_detection_config.dart';
import '../ui/pose_coordinate_mapper.dart';
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

  GameFootMarkerController? _gameFootMarker;

  bool? _lockedIsLeft;
  KickingFoot? get kickingFoot => _lockedIsLeft == null
      ? null
      : (_lockedIsLeft! ? KickingFoot.left : KickingFoot.right);

  Offset? _neutralPosition;
  double? _neutralZ;
  Size? _imageSize;

  /// Rest position of the knee-down leg point, captured alongside the ankle
  /// neutral. The leg centre sits above the ankle, so lift/loft in a captured
  /// swing must be measured against this baseline, not the ankle's.
  Offset? _legNeutralPosition;

  final Queue<_FootFrame> _buffer = Queue<_FootFrame>();
  static const int _bufferSize = 6; // Fix 8: was 3, now ~200ms at 30fps

  /// Rolling-balls mode: no strike is ever emitted from the pose stream.
  /// The game asks for the leg's motion at the moment the ball reaches the
  /// pass circle instead (see [captureLegSwingKick]), which removes the
  /// Z-thrust and planted-foot gates from the equation entirely.
  bool instantCaptureMode = false;

  /// Knee-down (knee/ankle/heel/toe) samples of the kicking leg, tracked on
  /// every pose frame regardless of arming so a capture can be taken at any
  /// instant. The whole lower leg is used instead of the ankle alone because
  /// the ankle drops in and out of confidence at foot-level camera angles,
  /// while the knee stays visible through the entire swing.
  final Queue<_FootFrame> _legBuffer = Queue<_FootFrame>();
  static const int _legBufferSize = 14;

  /// Leg samples this fresh count toward a capture. Generous, because pose
  /// frames arrive well below render rate and the swing that struck the ball
  /// may have peaked a few frames before the ball reached the circle.
  static const Duration _legCaptureWindow = Duration(milliseconds: 500);

  /// If the window holds fewer than two samples (pose stream hiccup), fall
  /// back to the last two samples as long as the newest is at least this
  /// recent — better than scoring a miss the player didn't make.
  static const Duration _legCaptureMaxStaleness = Duration(milliseconds: 420);

  /// Per-frame leg travel (normalized) that reads as a swing.
  static const double _legCaptureMinSpeed = 0.006;

  /// Total leg travel across the window that reads as a swing even when no
  /// single frame was fast (slow pose delivery smears a kick over frames).
  static const double _legCaptureMinTravel = 0.035;

  /// Floor for captured power so a slow-but-real contact still travels.
  static const double _legCaptureMinPower = 0.28;

  DateTime? _lastRollCaptureLog;
  static const Duration _rollCaptureLogCooldown = Duration(milliseconds: 400);

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
  int _plantedFootMissingFrames = 0; // Fix 6

  final StreamController<bool> _playerIsStillController =
      StreamController<bool>.broadcast();

  /// True when both ankles moved less than [KickDetectionConfig.plantedFootMaxMove]
  /// for 4 consecutive frames (same pose frames as kick detection).
  Stream<bool> get playerIsStill => _playerIsStillController.stream;

  final StreamController<bool> _kickingFootVisibleController =
      StreamController<bool>.broadcast();

  /// True when the locked kicking-foot ankle is detected with enough confidence.
  Stream<bool> get kickingFootVisible => _kickingFootVisibleController.stream;

  static const int _stillFramesRequired = 4;

  /// Foot rise above rest (normalized image height) that maps to loft = 1.0.
  /// A controlled aerial rises ~0.07–0.12; a ballooned over-hit exceeds this.
  /// Higher = more forgiving (a given rise reads as less loft).
  static const double _loftReferenceRise = 0.28;

  Offset? _stillPrevLeft;
  Offset? _stillPrevRight;
  int _consecutiveBothStillFrames = 0;
  bool _lastEmittedStill = false;
  bool _lastEmittedFootVisible = true;

  void updateImageSize(Size size) {
    _imageSize = size;
  }

  void setKickingFoot(KickingFoot foot) {
    _lockedIsLeft = foot.isLeft;
    _legBuffer.clear();
    _resetTrackingState();
    disableKicks();
  }

  void setMirrorPreviewAim(bool value) {
    // Retained for API compat; mirror is handled in PoseCoordinateMapper.
  }

  void bindGameFootMarker(GameFootMarkerController controller) {
    _gameFootMarker = controller;
  }

  void clearKickingFoot() {
    _lockedIsLeft = null;
    _legBuffer.clear();
    _resetTrackingState();
    disableKicks();
  }

  void applyCalibration(Offset neutralPosition, {double? neutralZ}) {
    _neutralPosition = neutralPosition;
    _neutralZ = neutralZ;
    // The player is standing in their rest stance right now.
    _legNeutralPosition = _averageLegPosition();
    _detectionArmed = false;
    _resetTrackingState();
    _phase = KickPhase.idle;
    _cooldownTimer?.cancel();
    debugPrint(
      '[KD] calibration applied — neutral=(${neutralPosition.dx.toStringAsFixed(2)}, '
      '${neutralPosition.dy.toStringAsFixed(2)}) neutralZ=${neutralZ?.toStringAsFixed(1) ?? 'null'}',
    );
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
    _neutralZ = null;
    _legNeutralPosition = null;
    _gameFootMarker?.endGameMode();
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
    _plantedFootMissingFrames = 0;
    _stillPrevLeft = null;
    _stillPrevRight = null;
    _consecutiveBothStillFrames = 0;
  }

  // ---------------------------------------------------------------------------
  // Frame processing
  // ---------------------------------------------------------------------------

  void _onPoseFrame(List<PoseLandmark> landmarks) {
    if (_lockedIsLeft == null) return;

    final imageSize = _imageSize;
    if (imageSize == null) return;

    _updatePlayerStillness(landmarks, imageSize);

    // Marker is visual-only — update it regardless of detection gates so the
    // foot marker tracks depth (run-up) even when kick detection is disarmed.
    // Deliberately skip _isTeleport: that check uses _lastAcceptedPosition
    // which is only updated inside the armed gate, so during run-up the
    // accumulated delta grows stale and silently blocks every frame.
    final kickingForMarker = _sampleKickingAnkle(landmarks, imageSize);
    final leg = _trackKneeDownLeg(landmarks, imageSize);
    _emitKickingFootVisible(
      kickingForMarker != null || (instantCaptureMode && leg != null),
    );

    // Instant-capture mode drives the marker off the same knee-down point the
    // capture reads, so what's on screen is what the shot will be taken from.
    final markerPoint = instantCaptureMode
        ? (_markerPointForLeg(leg?.position) ?? kickingForMarker?.position)
        : kickingForMarker?.position;
    if (markerPoint != null) {
      final footScale = _sampleKickingFootScale(landmarks, imageSize);
      _gameFootMarker?.updateFromFoot(
        markerPoint,
        footScale: footScale,
        ankleZ: kickingForMarker?.z,
      );
    }

    if (instantCaptureMode) return;

    if (!_detectionArmed) return;

    if (_phase == KickPhase.cooldown) {
      return;
    }

    if (!_gameCanAcceptKick) {
      return;
    }

    final kicking = kickingForMarker ?? _sampleKickingAnkle(landmarks, imageSize);
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
    } else {
      final marker = _gameFootMarker;
      final eligible = marker?.isEligibleForStrike ?? false;
      if (eligible) {
        // The marker has visibly crossed the ball this swing. Treat the
        // pass + meaningful foot motion as authoritative evidence of a
        // real kick, bypassing the stricter z-thrust / planted-foot gates
        // that can miss pure lateral swings or curve-through follow-throughs.
        if (metrics.runupRejected) {
          debugPrint('[KD] strike via marker pass — plant check bypassed');
          _emitStrike(metrics);
        } else if (metrics.xySpeed >=
            _config.strikeSpeedThreshold * 0.6) {
          debugPrint('[KD] strike via marker pass — z-thrust skipped '
              '(xySpeed=${metrics.xySpeed.toStringAsFixed(3)})');
          _emitStrike(metrics);
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Sampling
  // ---------------------------------------------------------------------------

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
      position: PoseCoordinateMapper.landmarkToNormalized(
        landmark: ankle,
        imageSize: imageSize,
        isFrontCamera: PoseDetectorService.instance.isFrontCamera,
      ),
      z: ankle.z,
      confidence: ankle.likelihood,
    );
  }

  /// Body-scale proxy for depth tracking.
  ///
  /// At foot-level camera, the lower body is by far the most visible part.
  /// We measure shin length (ankle→knee) on BOTH legs and average the valid
  /// readings. Using both legs averages out the noise from individual leg
  /// motion during walking. Confidence threshold is lowered because at foot
  /// level even partial detections contain usable geometry.
  ///
  /// Falls back to hip→ankle, then hip-to-hip, then single-leg shin if only
  /// one side is visible.
  double? _sampleKickingFootScale(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    if (_lockedIsLeft == null) return null;

    final byType = {for (final l in landmarks) l.type: l};
    final isFront = PoseDetectorService.instance.isFrontCamera;
    Offset toNorm(PoseLandmark lm) => PoseCoordinateMapper.landmarkToNormalized(
          landmark: lm,
          imageSize: imageSize,
          isFrontCamera: isFront,
        );

    bool ok(PoseLandmark? lm) =>
        lm != null && lm.likelihood >= 0.3;

    final lAnkle = byType[PoseLandmarkType.leftAnkle];
    final rAnkle = byType[PoseLandmarkType.rightAnkle];
    final lKnee = byType[PoseLandmarkType.leftKnee];
    final rKnee = byType[PoseLandmarkType.rightKnee];

    // Primary: average both shins (ankle→knee). Most visible at foot level.
    final shinSamples = <double>[];
    if (ok(lAnkle) && ok(lKnee)) {
      shinSamples.add((toNorm(lAnkle!) - toNorm(lKnee!)).distance);
    }
    if (ok(rAnkle) && ok(rKnee)) {
      shinSamples.add((toNorm(rAnkle!) - toNorm(rKnee!)).distance);
    }
    if (shinSamples.isNotEmpty) {
      return shinSamples.reduce((a, b) => a + b) / shinSamples.length;
    }

    // Fallback: hip→ankle (full leg)
    final lHip = byType[PoseLandmarkType.leftHip];
    final rHip = byType[PoseLandmarkType.rightHip];
    final legSamples = <double>[];
    if (ok(lHip) && ok(lAnkle)) {
      legSamples.add((toNorm(lHip!) - toNorm(lAnkle!)).distance);
    }
    if (ok(rHip) && ok(rAnkle)) {
      legSamples.add((toNorm(rHip!) - toNorm(rAnkle!)).distance);
    }
    if (legSamples.isNotEmpty) {
      return legSamples.reduce((a, b) => a + b) / legSamples.length;
    }

    // Last resort: hip-to-hip span
    if (ok(lHip) && ok(rHip)) {
      return (toNorm(lHip!) - toNorm(rHip!)).distance;
    }
    return null;
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
      position: PoseCoordinateMapper.landmarkToNormalized(
        landmark: ankle,
        imageSize: imageSize,
        isFrontCamera: PoseDetectorService.instance.isFrontCamera,
      ),
      confidence: ankle.likelihood,
    );
  }

  // ---------------------------------------------------------------------------
  // Knee-down leg tracking (rolling-balls instant capture)
  // ---------------------------------------------------------------------------

  ({Offset position, double confidence})? _trackKneeDownLeg(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    final leg = _sampleKneeDownLeg(landmarks, imageSize);
    if (leg == null) return null;
    _legBuffer.addLast(
      _FootFrame(
        positionNormalized: leg.position,
        z: 0,
        confidence: leg.confidence,
        timestamp: DateTime.now(),
      ),
    );
    while (_legBuffer.length > _legBufferSize) {
      _legBuffer.removeFirst();
    }
    return leg;
  }

  /// The tracked leg point shifted into the ankle's frame of reference, so the
  /// on-screen marker still rests on its anchor below the ball while moving
  /// with the whole lower leg.
  Offset? _markerPointForLeg(Offset? legPosition) {
    if (legPosition == null) return null;
    final legNeutral = _legNeutralPosition;
    final ankleNeutral = _neutralPosition;
    if (legNeutral == null || ankleNeutral == null) return legPosition;
    return legPosition - (legNeutral - ankleNeutral);
  }

  /// Weighted centre of the kicking leg from the knee down. Weights lean
  /// toward the foot (that's what strikes the ball) while the knee keeps the
  /// point stable when the toe/heel flicker out of view.
  ({Offset position, double confidence})? _sampleKneeDownLeg(
    List<PoseLandmark> landmarks,
    Size imageSize,
  ) {
    final locked = _lockedIsLeft;
    if (locked == null) return null;

    final byType = {for (final l in landmarks) l.type: l};
    final weights = <PoseLandmarkType, double>{
      locked ? PoseLandmarkType.leftKnee : PoseLandmarkType.rightKnee: 0.25,
      locked ? PoseLandmarkType.leftAnkle : PoseLandmarkType.rightAnkle: 0.4,
      locked ? PoseLandmarkType.leftHeel : PoseLandmarkType.rightHeel: 0.15,
      locked
          ? PoseLandmarkType.leftFootIndex
          : PoseLandmarkType.rightFootIndex: 0.2,
    };

    // Lower-leg points sit at the edge of the frame at foot-level angles and
    // blur during the swing itself, so accept them far below the strike
    // confidence used for the ankle-only model — losing the swing frames is
    // what makes a real kick read as a miss.
    const minLikelihood = 0.25;
    final isFront = PoseDetectorService.instance.isFrontCamera;

    var weightSum = 0.0;
    var confidenceSum = 0.0;
    var x = 0.0;
    var y = 0.0;
    weights.forEach((type, weight) {
      final landmark = byType[type];
      if (landmark == null || landmark.likelihood < minLikelihood) return;
      final norm = PoseCoordinateMapper.landmarkToNormalized(
        landmark: landmark,
        imageSize: imageSize,
        isFrontCamera: isFront,
      );
      x += norm.dx * weight;
      y += norm.dy * weight;
      confidenceSum += landmark.likelihood * weight;
      weightSum += weight;
    });

    // A single visible joint (usually the knee) is enough to keep tracking.
    if (weightSum < 0.15) return null;
    return (
      position: Offset(x / weightSum, y / weightSum),
      confidence: confidenceSum / weightSum,
    );
  }

  Offset? _averageLegPosition() {
    if (_legBuffer.isEmpty) return null;
    var sum = Offset.zero;
    for (final frame in _legBuffer) {
      sum += frame.positionNormalized;
    }
    return sum / _legBuffer.length.toDouble();
  }

  /// Snapshot of the kicking leg's motion right now, mapped into a
  /// [KickEvent] — used by rolling-balls mode, where the ball is struck at the
  /// instant it reaches the pass circle rather than when a Z-thrust is seen.
  /// Returns null when the leg is missing or effectively still, meaning the
  /// player didn't make contact and the ball should roll on.
  KickEvent? captureLegSwingKick() {
    if (_lockedIsLeft == null) return null;

    final now = DateTime.now();
    var frames = _legBuffer
        .where((f) => now.difference(f.timestamp) <= _legCaptureWindow)
        .toList();
    if (frames.length < 2 && _legBuffer.length >= 2) {
      final all = _legBuffer.toList();
      if (now.difference(all.last.timestamp) <= _legCaptureMaxStaleness) {
        frames = all.sublist(all.length - 2);
      }
    }
    if (frames.length < 2) {
      _logRollCapture('[KD] roll capture — leg not tracked at ball arrival');
      return null;
    }

    // Fastest frame in the window is where contact happened — the leg may have
    // already begun decelerating by the time the ball reached the circle.
    var peakIdx = frames.length - 1;
    var xySpeed = 0.0;
    for (var i = 1; i < frames.length; i++) {
      final d = (frames[i].positionNormalized - frames[i - 1].positionNormalized)
          .distance;
      if (d > xySpeed) {
        xySpeed = d;
        peakIdx = i;
      }
    }

    final contact = frames[peakIdx];
    final swingDelta =
        contact.positionNormalized - frames.first.positionNormalized;
    final windowTravel = swingDelta.distance;

    if (xySpeed < _legCaptureMinSpeed && windowTravel < _legCaptureMinTravel) {
      _logRollCapture(
        '[KD] roll capture — leg still (speed=${xySpeed.toStringAsFixed(3)} '
        'travel=${windowTravel.toStringAsFixed(3)})',
      );
      return null;
    }

    final contactDelta =
        contact.positionNormalized - frames[peakIdx - 1].positionNormalized;

    // Take whichever reads faster: the single quickest frame, or the whole
    // window's travel. A kick smeared across slow pose frames still hits hard.
    final peakVelocity = _velocityOf(
      xySpeed,
      frames[peakIdx - 1].timestamp,
      contact.timestamp,
    );
    final windowVelocity = _velocityOf(
      windowTravel,
      frames.first.timestamp,
      contact.timestamp,
    );
    final velocity =
        peakVelocity > windowVelocity ? peakVelocity : windowVelocity;
    final power = (velocity / _config.maxXyVelocityNorm)
        .clamp(_legCaptureMinPower, 1.0);

    final sensorDegrees =
        PoseDetectorService.instance.cameraSensorOrientation ??
        PoseDetectorService.instance.sensorRotationDegrees ??
        0;

    final neutral = _legNeutralPosition ?? contact.positionNormalized;

    Offset neutralAimBoost = Offset.zero;
    if (_legNeutralPosition != null && swingDelta.distance < 0.02) {
      neutralAimBoost = (contact.positionNormalized - neutral) * 0.5;
    }

    final aimDelta = _lateralAimDelta(
      swingDelta + neutralAimBoost,
      contactDelta,
      sensorDegrees,
    );
    final normalizedAim = Offset(
      (aimDelta.dx / _config.aimReferenceDelta).clamp(-1.0, 1.0),
      aimDelta.dy,
    );
    final lateralAimWide =
        (aimDelta.dx / _config.aimReferenceDelta).clamp(-1.6, 1.6);

    final kickType = _classifyType(
      footPos: contact.positionNormalized,
      neutralPos: neutral,
      xyDelta: contactDelta,
      swingDelta: swingDelta,
      xySpeed: xySpeed,
    );
    final loft =
        ((neutral.dy - contact.positionNormalized.dy) / _loftReferenceRise)
            .clamp(0.0, 1.0);

    final event = KickEvent(
      footPositionNormalized: contact.positionNormalized,
      strikeDeltaNormalized: normalizedAim,
      strikeSpeed: xySpeed,
      kickPower: power,
      type: kickType,
      timestamp: now,
      spinX: _computeSpinX(frames, peakIdx),
      loft: loft,
      lateralAim: lateralAimWide,
    );

    _gameFootMarker?.onShotFired();
    debugPrint(
      '[KD] ══ ROLL CAPTURE ══ frames=${frames.length} '
      'speed=${xySpeed.toStringAsFixed(3)} '
      'travel=${windowTravel.toStringAsFixed(3)} '
      'power=${power.toStringAsFixed(2)} '
      'aim=(${normalizedAim.dx.toStringAsFixed(2)}, '
      '${normalizedAim.dy.toStringAsFixed(3)}) type=${kickType.name}',
    );
    return event;
  }

  /// Normalized units per second between two samples. The gap is clamped so a
  /// stalled pose stream can't read as an impossibly slow (or fast) swing.
  double _velocityOf(double distance, DateTime from, DateTime to) {
    final ms = to.difference(from).inMicroseconds / 1000.0;
    return distance / (ms.clamp(16.0, 220.0) / 1000.0);
  }

  void _logRollCapture(String message) {
    final now = DateTime.now();
    if (_lastRollCaptureLog != null &&
        now.difference(_lastRollCaptureLog!) < _rollCaptureLogCooldown) {
      return;
    }
    _lastRollCaptureLog = now;
    debugPrint(message);
  }

  // ---------------------------------------------------------------------------
  // Teleport filter
  // ---------------------------------------------------------------------------

  double _teleportDelta(Offset position) {
    final last = _lastAcceptedPosition;
    if (last == null) return 0;
    return (position - last).distance;
  }

  bool _isTeleport(Offset position, double confidence) {
    final delta = _teleportDelta(position);
    if (delta <= _config.maxPlausibleMovement) return false;
    if (confidence >= _config.minConfidence &&
        delta < _config.maxKickMotionPerFrame * 1.35) {
      return false;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Kick evaluation (core logic)
  // ---------------------------------------------------------------------------

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

    // --- XY delta & speed ---
    final xyDelta = curr.positionNormalized - prev.positionNormalized;
    final xySpeed = xyDelta.distance;
    final zDelta = curr.z - prev.z;

    // --- Fix 5: Timestamp-normalized velocity ---
    final elapsedMs =
        curr.timestamp.difference(prev.timestamp).inMicroseconds / 1000.0;
    final elapsedSecs = elapsedMs.clamp(16.0, 100.0) / 1000.0;
    final xyVelocity = xySpeed / elapsedSecs;
    final zSpeed = (-zDelta).clamp(0.0, 200.0) / 200.0;
    final combinedPower = ((xyVelocity / _config.maxXyVelocityNorm) * 0.65 +
            zSpeed * 0.35)
        .clamp(0.0, 1.0);

    // --- Planted foot (Fix 6) ---
    final plantedIsLeft = !_lockedIsLeft!;
    final planted = _samplePlantedAnkle(landmarks, imageSize);
    double plantMove;

    if (planted != null) {
      _plantedFootMissingFrames = 0;
      final prevPlanted = _lastPlantedPositions[plantedIsLeft];
      if (prevPlanted != null) {
        plantMove = (planted.position - prevPlanted).distance;
      } else {
        plantMove = _config.plantedFootMaxMove; // neutral first frame
      }
      _lastPlantedPositions[plantedIsLeft] = planted.position;
    } else {
      if (_plantedFootMissingFrames < _config.maxPlantedMissingFrames) {
        plantMove = 0; // assume still — can't measure
        _plantedFootMissingFrames++;
      } else {
        plantMove = double.infinity;
      }
    }

    // --- Z thrust ---
    final zScale = _zScale(prev.z, curr.z);
    final zThrust = _isZThrust(zDelta, zScale) &&
        (_buffer.length < 3 ||
            _isZThrust(prev.z - frames[frames.length - 3].z, zScale));

    final speedOk = xySpeed >= _config.strikeSpeedThreshold;
    final plantOk = plantMove <= _config.plantedFootMaxMove;

    final runupRejected = zThrust && speedOk && !plantOk;
    final isKick = zThrust && speedOk && plantOk;
    final zThrustCandidate = _isZThrust(zDelta, zScale);

    // --- Fix 8: Peak-speed aim window ---
    final sensorDegrees =
        PoseDetectorService.instance.cameraSensorOrientation ??
        PoseDetectorService.instance.sensorRotationDegrees ??
        0;

    int peakIdx = frames.length - 1;
    double peakSpeed = 0;
    for (int i = 1; i < frames.length; i++) {
      final d = (frames[i].positionNormalized -
              frames[i - 1].positionNormalized)
          .distance;
      if (d > peakSpeed) {
        peakSpeed = d;
        peakIdx = i;
      }
    }

    final windowDelta =
        frames[peakIdx].positionNormalized - frames.first.positionNormalized;
    final instantDelta = xyDelta;

    // Fix 1: cross-reference neutral baseline when window delta is small
    Offset neutralAimBoost = Offset.zero;
    if (_neutralPosition != null && windowDelta.distance < 0.02) {
      neutralAimBoost =
          (curr.positionNormalized - _neutralPosition!) * 0.5;
    }

    final aimDelta = _lateralAimDelta(
      windowDelta + neutralAimBoost,
      instantDelta,
      sensorDegrees,
    );
    // Fix 9: clamp ±1.0 (was ±1.5)
    final normalizedAim = Offset(
      (aimDelta.dx / _config.aimReferenceDelta).clamp(-1.0, 1.0),
      aimDelta.dy,
    );
    // Same lateral aim but clamped WIDER, so a swing well past a corner keeps
    // its magnitude. Placement still uses the ±1 value; this only flags shots
    // that are aimed so far to the side they should miss wide of the post.
    final lateralAimWide =
        (aimDelta.dx / _config.aimReferenceDelta).clamp(-1.6, 1.6);

    // --- Fix 1 + 4: classify type relative to neutral ---
    final kickType = _classifyType(
      footPos: curr.positionNormalized,
      neutralPos: _neutralPosition ?? curr.positionNormalized,
      xyDelta: xyDelta,
      swingDelta: windowDelta,
      xySpeed: xySpeed,
    );

    // Loft: how far the foot rose above rest at strike, normalized so a very
    // high (ballooned) hit approaches 1.0. Used downstream to send extreme
    // over-hits into the crossbar instead of the top of the net.
    final relativeRise =
        (_neutralPosition ?? curr.positionNormalized).dy -
            curr.positionNormalized.dy;
    final loft = (relativeRise / _loftReferenceRise).clamp(0.0, 1.0);

    // --- Curve / swing detection ---
    //
    // Measure how much the foot path bent away from a straight line drawn
    // from swing-start to swing-end. We look at the X-coordinate of the
    // peak-speed frame compared to the X you'd expect if the foot had
    // travelled in a perfectly straight line over the same time fraction.
    // Positive deviation → foot arced to screen-right → ball curves right.
    // Negative deviation → foot arced to screen-left  → ball curves left.
    // A dead zone keeps tiny natural curves from producing any spin.
    final spinX = _computeSpinX(frames, peakIdx);

    return _KickMetrics(
      xySpeed: xySpeed,
      zDelta: zDelta,
      plantMove: plantMove.isFinite ? plantMove : 999,
      isKick: isKick,
      runupRejected: runupRejected,
      rawDelta: xyDelta,
      correctedDelta: normalizedAim,
      footPosition: curr.positionNormalized,
      type: kickType,
      sensorDegrees: sensorDegrees,
      zThrustCandidate: zThrustCandidate,
      kickPower: combinedPower,
      spinX: spinX,
      loft: loft,
      lateralAim: lateralAimWide,
    );
  }

  /// Compute curve / swing factor in [-1, +1] from the foot trajectory.
  ///
  /// For every intermediate frame we measure the **signed perpendicular
  /// distance** from that frame to the straight line drawn from swing-start
  /// to swing-end. Perpendicular distance is invariant to where along the
  /// line the foot is at each frame, so a kick that simply accelerates from
  /// rest (real biomechanics!) registers zero curve — only an actual bowed
  /// foot path produces non-zero spin.
  ///
  /// Sign convention: positive perpendicular distance → foot bowed to the
  /// right of the A→B line in the mirrored selfie view → ball curves right.
  /// Negative → bowed to the left → ball curves left.
  double _computeSpinX(List<_FootFrame> frames, int peakIdx) {
    if (frames.length < 3) return 0;
    final start = frames.first.positionNormalized;
    final end = frames.last.positionNormalized;
    final swing = end - start;
    final swingLen = swing.distance;
    if (swingLen < _config.curveMinSwingLength) return 0;

    // Signed perpendicular distance of each intermediate frame from line A→B.
    // Using the 2D cross product divided by the swing length:
    //   cross(swing, AM) / |swing|
    // gives the magnitude AND the side the foot is on (independent of how
    // fast it was moving along the line at that moment).
    double maxAbs = 0;
    double signedAtMax = 0;
    final total = frames.length - 1;
    for (int i = 1; i < total; i++) {
      final am = frames[i].positionNormalized - start;
      final cross = swing.dx * am.dy - swing.dy * am.dx;
      final signedDist = cross / swingLen;
      if (signedDist.abs() > maxAbs) {
        maxAbs = signedDist.abs();
        signedAtMax = signedDist;
      }
    }

    if (maxAbs < _config.curveDeadZone) return 0;
    final excess = maxAbs - _config.curveDeadZone;
    final normalized = (excess / _config.curveReferenceDeviation)
        .clamp(0.0, 1.0);
    return signedAtMax.sign * normalized;
  }

  // ---------------------------------------------------------------------------
  // Aim helpers
  // ---------------------------------------------------------------------------

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

  /// PoseCoordinateMapper.landmarkToNormalized normalises into portrait-upright
  /// space (orientedImageSize swaps axes for 90/270°). Deltas are therefore
  /// already portrait-aligned. If aim is inverted on a specific device,
  /// set [KickDetectionConfig.flipAimXForDevice] true as a workaround. (Fix 3)
  Offset _correctDeltaForSensor(Offset rawDelta, int sensorDegrees) {
    if (_config.flipAimXForDevice) return Offset(-rawDelta.dx, rawDelta.dy);
    return rawDelta;
  }

  // ---------------------------------------------------------------------------
  // Shot type classification (Fix 1 + Fix 4)
  // ---------------------------------------------------------------------------

  KickType _classifyType({
    required Offset footPos,
    required Offset neutralPos,
    required Offset xyDelta,
    required Offset swingDelta,
    required double xySpeed,
  }) {
    // Relative height above neutral: positive = foot is higher than rest position
    final relativeRise = neutralPos.dy - footPos.dy; // dy inverted: up = smaller y
    final verticalLift = -xyDelta.dy; // negative dy = moving up

    // Chip: slower-speed, slightly-lifted kick
    if (xySpeed < _config.chipMaxSpeed &&
        xySpeed >= _config.strikeSpeedThreshold &&
        relativeRise > 0.04 &&
        relativeRise < 0.09) {
      return KickType.chip;
    }

    // A clear, intentional lift always lofts — respect the player raising
    // their foot regardless of any sideways sweep.
    if (relativeRise > _config.aerialRelativeRise) {
      return KickType.aerial;
    }

    // Borderline lift (modest rise + upward velocity): normally this lofts,
    // but if the swing is dominantly sideways (an inside-of-foot sweep) treat
    // it as a low, driven ground shot so players can bury it in the bottom
    // corners with pace instead of the ball floating up.
    if (relativeRise > _config.aerialMinRise &&
        verticalLift > _config.aerialMinLift) {
      final horizontalSwing = swingDelta.dx.abs();
      final verticalSwing = swingDelta.dy.abs();
      final isSideFootDrive =
          horizontalSwing > verticalSwing * _config.sideFootLateralRatio;
      return isSideFootDrive ? KickType.ground : KickType.aerial;
    }

    return KickType.ground;
  }

  // ---------------------------------------------------------------------------
  // Emit strike
  // ---------------------------------------------------------------------------

  void _emitStrike(_KickMetrics metrics) {
    final marker = _gameFootMarker;
    if (marker != null && marker.isGameMode && !marker.isEligibleForStrike) {
      debugPrint('[KD] strike ignored — marker did not pass the ball');
      return;
    }

    _phase = KickPhase.strike;
    marker?.onShotFired();

    final event = KickEvent(
      footPositionNormalized: metrics.footPosition,
      strikeDeltaNormalized: metrics.correctedDelta,
      strikeSpeed: metrics.xySpeed,
      kickPower: metrics.kickPower,
      type: metrics.type,
      timestamp: DateTime.now(),
      spinX: metrics.spinX,
      loft: metrics.loft,
      lateralAim: metrics.lateralAim,
    );

    debugPrint('');
    debugPrint('[KD] ══════ KICK DETECTED ══════');
    debugPrint(
      '[KD] STRIKE raw=(${metrics.rawDelta.dx.toStringAsFixed(3)}, '
      '${metrics.rawDelta.dy.toStringAsFixed(3)}) '
      'corrected=(${metrics.correctedDelta.dx.toStringAsFixed(3)}, '
      '${metrics.correctedDelta.dy.toStringAsFixed(3)}) '
      'sensor=${metrics.sensorDegrees} '
      'speed=${metrics.xySpeed.toStringAsFixed(3)} '
      'power=${metrics.kickPower.toStringAsFixed(2)} '
      'spin=${metrics.spinX.toStringAsFixed(2)} '
      'type=${metrics.type.name}',
    );
    debugPrint('[KD] ══════════════════════════');
    debugPrint('');

    _kickController.add(event);
    _enterCooldown();
  }

  // ---------------------------------------------------------------------------
  // Cooldown
  // ---------------------------------------------------------------------------

  void _enterCooldown() {
    _phase = KickPhase.cooldown;
    _buffer.clear();
    _lastAcceptedPosition = null;
    _lastPlantedPositions.clear();
    _plantedFootMissingFrames = 0;
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

  // ---------------------------------------------------------------------------
  // Z-depth helpers (Fix 10)
  // ---------------------------------------------------------------------------

  double _zScale(double prevZ, double currZ) {
    final neutralZ = _neutralZ ?? ((prevZ.abs() + currZ.abs()) * 0.5);
    return neutralZ.abs().clamp(40.0, 300.0);
  }

  bool _isZThrust(double zDelta, double zScale) {
    return zDelta < -_config.minZThrustPixels &&
        zDelta / zScale < -_config.minZThrustRelative;
  }

  // ---------------------------------------------------------------------------
  // Cooldown UI
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Logging
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // Player stillness (for match phase)
  // ---------------------------------------------------------------------------

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

  void _emitKickingFootVisible(bool visible) {
    if (visible == _lastEmittedFootVisible) return;
    _lastEmittedFootVisible = visible;
    if (!_kickingFootVisibleController.isClosed) {
      _kickingFootVisibleController.add(visible);
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
    return PoseCoordinateMapper.landmarkToNormalized(
      landmark: ankle,
      imageSize: imageSize,
      isFrontCamera: PoseDetectorService.instance.isFrontCamera,
    );
  }

  void dispose() {
    _cooldownTimer?.cancel();
    _cooldownUiTimer?.cancel();
    _subscription?.cancel();
    _kickController.close();
    _cooldownUiController.close();
    _playerIsStillController.close();
    _kickingFootVisibleController.close();
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
    required this.kickPower,
    this.spinX = 0,
    this.loft = 0,
    this.lateralAim = 0,
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
    kickPower: 0,
    spinX: 0,
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
        kickPower: 0,
        spinX: 0,
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
  final double kickPower;
  final double spinX;
  final double loft;
  final double lateralAim;
}
