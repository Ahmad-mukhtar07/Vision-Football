import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Wraps Google ML Kit pose detection and exposes a stream of pose results.
class PoseDetectorService {
  PoseDetectorService._();

  static final PoseDetectorService instance = PoseDetectorService._();

  static const int _processEveryNthFrame = 1;

  /// Lazily created so it can be released between sessions (see [release]).
  PoseDetector? _detector;

  PoseDetector _ensureDetector() {
    return _detector ??= PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
  }

  final StreamController<List<PoseLandmark>> _landmarksController =
      StreamController<List<PoseLandmark>>.broadcast();

  Stream<List<PoseLandmark>> get poseLandmarks => _landmarksController.stream;

  int _frameCounter = 0;
  bool _isProcessing = false;
  bool _disposed = false;

  /// When false, [processCameraImage] skips inference entirely. Toggled by the
  /// camera widget so ML Kit only runs during phases that consume poses
  /// (positioning / calibration / play) — not foot-selection, pause, or
  /// match-over. Active-gameplay behaviour is unchanged, so accuracy is too.
  bool _processingEnabled = true;

  void setProcessingEnabled(bool enabled) {
    _processingEnabled = enabled;
    if (!enabled) _isProcessing = false;
  }

  CameraDescription? _camera;
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  /// Raw camera buffer size (often landscape: width > height).
  Size? lastBufferImageSize;

  /// Upright size ML Kit landmark coords use (portrait: height > width).
  Size? lastImageSize;
  InputImageRotation? lastRotation;

  /// Maps buffer dimensions to upright portrait/landscape space for landmarks.
  static Size orientedImageSize(Size bufferSize, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(bufferSize.height, bufferSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return bufferSize;
    }
  }

  /// Raw [CameraDescription.sensorOrientation] (for kick aim correction).
  int? cameraSensorOrientation;

  /// Degrees passed to ML Kit for the last processed frame (0/90/180/270).
  int? sensorRotationDegrees;

  bool get isFrontCamera =>
      _camera?.lensDirection == CameraLensDirection.front;

  final List<double> _recentFrameIntervalsMs = [];
  DateTime? _lastProcessedAt;

  String? _lastErrorMessage;
  DateTime? _lastErrorLogTime;
  static const Duration _errorLogCooldown = Duration(seconds: 8);

  DateTime? _lastPoseLogTime;
  static const Duration _poseLogInterval = Duration(seconds: 3);

  /// Set true to print ankle coordinates every processed frame (very noisy).
  static bool enablePoseDebugLogs = false;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Call when the active [CameraDescription] or orientation changes.
  void bindCameraSession({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    _camera = camera;
    _deviceOrientation = deviceOrientation;
    cameraSensorOrientation = camera.sensorOrientation;
  }

  InputImageRotation _getInputImageRotation(int sensorDegrees) {
    switch (sensorDegrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (_disposed || _camera == null) return;
    if (!_processingEnabled) return;

    _frameCounter++;
    if (_frameCounter % _processEveryNthFrame != 0) return;
    if (_isProcessing) return;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    final meta = inputImage.metadata;
    if (meta != null) {
      lastBufferImageSize = meta.size;
      lastRotation = meta.rotation;
      lastImageSize = orientedImageSize(meta.size, meta.rotation);
    }

    if (_frameCounter == 1 || _frameCounter % 120 == 0) {
      final buf = lastBufferImageSize;
      final upright = lastImageSize;
      debugPrint(
        '[CAM] buffer=${buf?.width.toInt()}×${buf?.height.toInt()} '
        'upright=${upright?.width.toInt()}×${upright?.height.toInt()} '
        '(portrait: upright height > width)',
      );
      debugPrint(
        '[POSE] inputRotation=${lastRotation?.name ?? "?"} '
        'upright=${upright?.width.toInt()}×${upright?.height.toInt()}',
      );
    }

    _isProcessing = true;
    try {
      final poses = await _ensureDetector().processImage(inputImage);
      if (_disposed) return;

      final landmarks = poses.isNotEmpty
          ? poses.first.landmarks.values.toList(growable: false)
          : <PoseLandmark>[];

      _landmarksController.add(landmarks);
      if (lastImageSize != null) {
        _logAnkles(landmarks, lastImageSize!);
      }
      _recordFpsSample();
    } catch (e, _) {
      _logDetectionError(e);
    } finally {
      _isProcessing = false;
    }
  }

  void _logDetectionError(Object error) {
    final message = error.toString();
    final now = DateTime.now();
    if (_lastErrorMessage == message &&
        _lastErrorLogTime != null &&
        now.difference(_lastErrorLogTime!) < _errorLogCooldown) {
      return;
    }
    _lastErrorMessage = message;
    _lastErrorLogTime = now;
    debugPrint('[POSE] detection error: $message');
  }

  void _logAnkles(List<PoseLandmark> landmarks, Size imageSize) {
    if (!enablePoseDebugLogs) return;
    final now = DateTime.now();
    if (_lastPoseLogTime != null &&
        now.difference(_lastPoseLogTime!) < _poseLogInterval) {
      return;
    }
    _lastPoseLogTime = now;

    final byType = {for (final l in landmarks) l.type: l};
    final left = byType[PoseLandmarkType.leftAnkle];
    final right = byType[PoseLandmarkType.rightAnkle];

    String fmt(PoseLandmark? l) {
      if (l == null) return '—';
      final nx = (l.x > 2.0 ? l.x / imageSize.width : l.x).toStringAsFixed(3);
      final ny = (l.y > 2.0 ? l.y / imageSize.height : l.y).toStringAsFixed(3);
      final conf = l.likelihood.toStringAsFixed(2);
      return '($nx, $ny, $conf)';
    }

    final fps = _rollingFps().toStringAsFixed(1);
    debugPrint(
      '[POSE] L_ankle=${fmt(left)} R_ankle=${fmt(right)} fps=$fps',
    );
  }

  void _recordFpsSample() {
    final now = DateTime.now();
    if (_lastProcessedAt != null) {
      final intervalMs =
          now.difference(_lastProcessedAt!).inMicroseconds / 1000.0;
      _recentFrameIntervalsMs.add(intervalMs);
      if (_recentFrameIntervalsMs.length > 10) {
        _recentFrameIntervalsMs.removeAt(0);
      }
    }
    _lastProcessedAt = now;
  }

  double _rollingFps() {
    if (_recentFrameIntervalsMs.isEmpty) return 0;
    final avgMs = _recentFrameIntervalsMs.reduce((a, b) => a + b) /
        _recentFrameIntervalsMs.length;
    if (avgMs <= 0) return 0;
    return 1000 / avgMs;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _camera!;

    InputImageRotation? rotation;
    int? rotationDegrees;
    if (Platform.isIOS) {
      rotationDegrees = camera.sensorOrientation;
      rotation = _getInputImageRotation(rotationDegrees);
    } else if (Platform.isAndroid) {
      final rotationCompensation = _orientations[_deviceOrientation];
      if (rotationCompensation == null) return null;

      rotationDegrees = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + rotationCompensation) % 360
          : (camera.sensorOrientation - rotationCompensation + 360) % 360;
      rotation = _getInputImageRotation(rotationDegrees);
    }
    if (rotation == null || rotationDegrees == null) return null;

    sensorRotationDegrees = rotationDegrees;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid) {
      return _androidInputImage(image, rotation);
    }
    if (Platform.isIOS && format == InputImageFormat.bgra8888) {
      if (image.planes.length != 1) return null;
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }
    return null;
  }

  InputImage? _androidInputImage(
    CameraImage image,
    InputImageRotation rotation,
  ) {
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format != InputImageFormat.nv21 || image.planes.length != 1) {
      return null;
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  /// Frees the native ML Kit detector while keeping the singleton reusable.
  /// Call on screen exit; the next session lazily recreates the detector.
  Future<void> release() async {
    _processingEnabled = false;
    _isProcessing = false;
    _frameCounter = 0;
    final detector = _detector;
    _detector = null;
    await detector?.close();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _detector?.close();
    _detector = null;
    await _landmarksController.close();
  }
}
