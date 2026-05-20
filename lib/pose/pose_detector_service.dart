import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Wraps Google ML Kit pose detection and exposes a stream of pose results.
///
/// Landmark [x]/[y] from ML Kit are in input-image pixel space; normalize to
/// 0.0–1.0 by dividing by [lastImageSize] width/height when needed downstream.
class PoseDetectorService {
  PoseDetectorService._();

  static final PoseDetectorService instance = PoseDetectorService._();

  static const int _processEveryNthFrame = 3;

  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(
      model: PoseDetectionModel.base,
      mode: PoseDetectionMode.stream,
    ),
  );

  final StreamController<List<PoseLandmark>> _landmarksController =
      StreamController<List<PoseLandmark>>.broadcast();

  Stream<List<PoseLandmark>> get poseLandmarks => _landmarksController.stream;

  int _frameCounter = 0;
  bool _isProcessing = false;
  bool _disposed = false;

  CameraDescription? _camera;
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  Size? lastImageSize;
  InputImageRotation? lastRotation;

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
  }

  /// Maps sensor/device-compensated degrees to [InputImageRotation] for ML Kit.
  InputImageRotation _getRotation(int sensorDegrees) {
    return InputImageRotationValue.fromRawValue(sensorDegrees) ??
        InputImageRotation.rotation0deg;
  }

  Future<void> processCameraImage(CameraImage image) async {
    if (_disposed || _camera == null) return;

    _frameCounter++;
    if (_frameCounter % _processEveryNthFrame != 0) return;
    if (_isProcessing) return;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    lastImageSize = inputImage.metadata?.size;
    lastRotation = inputImage.metadata?.rotation;

    _isProcessing = true;
    try {
      final poses = await _detector.processImage(inputImage);
      if (_disposed) return;

      final landmarks = poses.isNotEmpty
          ? poses.first.landmarks.values.toList(growable: false)
          : <PoseLandmark>[];

      _landmarksController.add(landmarks);
      _logAnkles(landmarks, inputImage.metadata!.size);
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
      final nx = (l.x / imageSize.width).toStringAsFixed(3);
      final ny = (l.y / imageSize.height).toStringAsFixed(3);
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
    if (Platform.isIOS) {
      rotation = _getRotation(camera.sensorOrientation);
    } else if (Platform.isAndroid) {
      final rotationCompensation =
          _orientations[_deviceOrientation];
      if (rotationCompensation == null) return null;

      final compensated = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + rotationCompensation) % 360
          : (camera.sensorOrientation - rotationCompensation + 360) % 360;
      rotation = _getRotation(compensated);
    }
    if (rotation == null) return null;

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

  /// Android: NV21 single-plane only (matches [ImageFormatGroup.nv21] + ML Kit).
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _detector.close();
    await _landmarksController.close();
  }
}
