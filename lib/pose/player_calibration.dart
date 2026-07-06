import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kicking_foot.dart';
import 'calibration_placement.dart';
import 'pose_detector_service.dart';
import 'stable_foot_tracker.dart';

enum CalibrationPhase {
  searching,
  holding,
  ready,
}

/// Samples a stable standing pose so aim/kicks use offsets from the player, not screen center.
class PlayerCalibration extends ChangeNotifier {
  PlayerCalibration({
    required Stream<List<PoseLandmark>> poseStream,
    this.stillSpeedThreshold = 0.014,
    this.stillFramesRequired = 5,
    this.minSamplesToForceComplete = 3,
    this.maxConsecutiveMissedFrames = 6,
    this.holdTimeout = const Duration(seconds: 45),
  }) : _footTracker = StableFootTracker(minConfidence: 0.68) {
    _subscription = poseStream.listen(_onPoseFrame);
  }

  StableFootTracker _footTracker;
  final double stillSpeedThreshold;
  final int stillFramesRequired;
  int get framesRequired => stillFramesRequired;
  final int minSamplesToForceComplete;
  final int maxConsecutiveMissedFrames;
  final Duration holdTimeout;

  static const double _referenceFrameMs = 33.0;
  static const double _maxMovementScaleCap = 3.5;

  StreamSubscription<List<PoseLandmark>>? _subscription;

  CalibrationPhase _phase = CalibrationPhase.searching;
  CalibrationPhase get phase => _phase;

  Offset? _neutralPosition;
  Offset? get neutralPosition => _neutralPosition;

  double? _neutralZ;
  double? get neutralZ => _neutralZ;

  bool get isReady => _phase == CalibrationPhase.ready && _neutralPosition != null;

  int get stillSampleCount => _stillSamples.length;

  double get progress =>
      (stillSampleCount / stillFramesRequired).clamp(0.0, 1.0);

  bool get hasKickingFoot => _lockedIsLeft != null;

  KickingFoot? get kickingFoot => _lockedIsLeft == null
      ? null
      : (_lockedIsLeft! ? KickingFoot.left : KickingFoot.right);

  /// Current framing problem (if any) for the kicking foot. Updated every
  /// frame while a kicking foot is set — during positioning preview and
  /// active calibration alike.
  CalibrationPlacementIssue _placement = CalibrationPlacementIssue.footNotVisible;
  CalibrationPlacementIssue get placement => _placement;

  bool get placementOk => _placement == CalibrationPlacementIssue.none;

  /// When true, the foot is locked purely to evaluate framing (positioning
  /// step); still-sample collection / calibration does not run yet.
  bool _placementPreviewOnly = false;

  Size? _imageSize;
  final List<Offset> _stillSamples = [];
  final List<double> _stillZSamples = [];
  Offset? _lastFootPosition;
  DateTime? _lastFootAt;
  DateTime? _holdStartedAt;
  bool? _lockedIsLeft;
  int _consecutiveMisses = 0;

  List<PoseLandmark>? _lastLandmarks;

  void updateImageSize(Size size) {
    _imageSize = size;
  }

  /// Lock the kicking foot only to evaluate framing during positioning.
  /// Calibration sampling stays paused until [setKickingFoot] is called.
  void beginPlacementPreview(KickingFoot foot) {
    _footTracker = StableFootTracker(minConfidence: 0.68);
    _footTracker.lockToFoot(foot.isLeft);
    _lockedIsLeft = foot.isLeft;
    _placementPreviewOnly = true;
    _placement = CalibrationPlacementIssue.footNotVisible;
    reset();
  }

  void setKickingFoot(KickingFoot foot) {
    _footTracker = StableFootTracker(minConfidence: 0.68);
    _footTracker.lockToFoot(foot.isLeft);
    _lockedIsLeft = foot.isLeft;
    _placementPreviewOnly = false;
    reset();
    debugPrint('[CALIBRATION] Tracking ${foot.bodyLabel} ankle only');
  }

  /// Use current samples or last seen foot position (when tracking is flaky).
  void forceComplete() {
    if (_lockedIsLeft == null) return;

    if (_stillSamples.length >= minSamplesToForceComplete) {
      _finishCalibration();
      return;
    }

    if (_lastFootPosition != null) {
      _neutralPosition = _lastFootPosition;
      _neutralZ = _sampleAnkleZ(_lastLandmarks, _imageSize);
      _phase = CalibrationPhase.ready;
      debugPrint(
        '[CALIBRATION] Forced ready (last seen) — '
        'neutral=(${_neutralPosition!.dx.toStringAsFixed(2)}, '
        '${_neutralPosition!.dy.toStringAsFixed(2)}) '
        'neutralZ=${_neutralZ?.toStringAsFixed(1) ?? 'null'}',
      );
      notifyListeners();
    }
  }

  void _onPoseFrame(List<PoseLandmark> landmarks) {
    final imageSize = _imageSize;
    if (imageSize == null || _lockedIsLeft == null) {
      return;
    }

    _updatePlacement(landmarks, imageSize);

    // During positioning we only evaluate framing; sampling starts later.
    if (_placementPreviewOnly || _phase == CalibrationPhase.ready) {
      return;
    }

    _lastLandmarks = landmarks;

    // Never lock in a neutral pose from bad framing — reset and wait for the
    // player to fix their position (the overlay tells them how).
    if (_placement != CalibrationPlacementIssue.none) {
      if (_stillSamples.isNotEmpty || _phase != CalibrationPhase.searching) {
        _stillSamples.clear();
        _stillZSamples.clear();
        _phase = CalibrationPhase.searching;
        _holdStartedAt = null;
        notifyListeners();
      }
      return;
    }

    if (_holdStartedAt != null &&
        DateTime.now().difference(_holdStartedAt!) > holdTimeout) {
      debugPrint('[CALIBRATION] Timed out — use Skip if your foot is visible');
      _resetCollection(keepPhase: true);
      notifyListeners();
      return;
    }

    final sample = _footTracker.sample(landmarks, imageSize);

    if (sample == null) {
      _consecutiveMisses++;
      if (_consecutiveMisses >= maxConsecutiveMissedFrames) {
        _stillSamples.clear();
        _stillZSamples.clear();
        _phase = CalibrationPhase.searching;
        _holdStartedAt = null;
        notifyListeners();
      }
      return;
    }

    _consecutiveMisses = 0;
    final foot = sample.position;
    final now = DateTime.now();

    if (_phase == CalibrationPhase.searching) {
      _phase = CalibrationPhase.holding;
      _holdStartedAt = now;
      _stillSamples.clear();
      _stillZSamples.clear();
      notifyListeners();
    }

    final previous = _lastFootPosition;
    final previousAt = _lastFootAt;
    _lastFootPosition = foot;
    _lastFootAt = now;

    if (previous != null && previousAt != null) {
      final speed = (foot - previous).distance;
      final elapsedMs = now.difference(previousAt).inMilliseconds;
      final scale =
          (elapsedMs / _referenceFrameMs).clamp(1.0, _maxMovementScaleCap);
      final allowance = stillSpeedThreshold * scale;

      if (speed > allowance) {
        if (_stillSamples.isNotEmpty) {
          debugPrint(
            '[CALIBRATION] Movement reset (${speed.toStringAsFixed(3)} > '
            '${allowance.toStringAsFixed(3)})',
          );
        }
        _stillSamples.clear();
        _stillZSamples.clear();
        notifyListeners();
        return;
      }
    }

    _stillSamples.add(foot);
    final z = _sampleAnkleZ(landmarks, imageSize);
    if (z != null) _stillZSamples.add(z);
    notifyListeners();

    if (_stillSamples.length < stillFramesRequired) return;

    _finishCalibration();
  }

  void _finishCalibration() {
    final sum = _stillSamples.fold<double>(0, (s, o) => s + o.dx);
    final sumY = _stillSamples.fold<double>(0, (s, o) => s + o.dy);
    final n = _stillSamples.length;
    _neutralPosition = Offset(sum / n, sumY / n);

    if (_stillZSamples.isNotEmpty) {
      _neutralZ = _stillZSamples.fold<double>(0, (s, v) => s + v) /
          _stillZSamples.length;
    }

    _phase = CalibrationPhase.ready;
    _stillSamples.clear();
    _stillZSamples.clear();
    debugPrint(
      '[CALIBRATION] Ready — neutral=(${_neutralPosition!.dx.toStringAsFixed(2)}, '
      '${_neutralPosition!.dy.toStringAsFixed(2)}) '
      'neutralZ=${_neutralZ?.toStringAsFixed(1) ?? 'null'}',
    );
    notifyListeners();
  }

  void _updatePlacement(List<PoseLandmark> landmarks, Size imageSize) {
    final foot = kickingFoot;
    if (foot == null) return;
    final next = CalibrationPlacement.evaluate(
      landmarks: landmarks,
      imageSize: imageSize,
      foot: foot,
      isFrontCamera: PoseDetectorService.instance.isFrontCamera,
    );
    if (next != _placement) {
      _placement = next;
      notifyListeners();
    }
  }

  double? _sampleAnkleZ(List<PoseLandmark>? landmarks, Size? imageSize) {
    if (landmarks == null || imageSize == null || _lockedIsLeft == null) {
      return null;
    }
    final byType = {for (final l in landmarks) l.type: l};
    final ankle = _lockedIsLeft!
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    return ankle?.z;
  }

  void reset() {
    _phase = CalibrationPhase.searching;
    _neutralPosition = null;
    _neutralZ = null;
    _stillSamples.clear();
    _stillZSamples.clear();
    _lastFootPosition = null;
    _lastFootAt = null;
    _holdStartedAt = null;
    _consecutiveMisses = 0;
    debugPrint(
      '[CALIBRATION] Reset — hold your ${kickingFoot?.bodyLabel ?? 'foot'} still',
    );
    notifyListeners();
  }

  void clearKickingFoot() {
    _lockedIsLeft = null;
    _placementPreviewOnly = false;
    _placement = CalibrationPlacementIssue.footNotVisible;
    _phase = CalibrationPhase.searching;
    _neutralPosition = null;
    _neutralZ = null;
    _stillSamples.clear();
    _stillZSamples.clear();
    _lastFootPosition = null;
    _lastFootAt = null;
    _holdStartedAt = null;
    _consecutiveMisses = 0;
    notifyListeners();
  }

  void _resetCollection({bool keepPhase = false}) {
    _stillSamples.clear();
    _stillZSamples.clear();
    _lastFootPosition = null;
    _lastFootAt = null;
    if (!keepPhase) {
      _phase = CalibrationPhase.searching;
      _holdStartedAt = null;
    }
    _consecutiveMisses = 0;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
