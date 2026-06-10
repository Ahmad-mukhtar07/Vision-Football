import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// One sample of detected hand positions.
///
/// Coordinates are in normalized image space (0..1) with the front-camera
/// horizontal mirror already applied — so `leftHand.dx ≈ 0` means the
/// player's hand appears at the LEFT edge of the screen.
class HandFrame {
  const HandFrame({
    required this.leftHand,
    required this.rightHand,
    required this.imageSize,
    required this.timestamp,
  });

  final Offset? leftHand;
  final Offset? rightHand;
  final Size? imageSize;
  final DateTime timestamp;
}

/// Self-contained hand-tracking pipeline for goalkeeper mode.
///
/// Uses Google ML Kit pose detection under the hood and consumes only the
/// wrist landmarks (treated as "hand" positions). This keeps the keeper
/// pipeline completely independent from [PoseDetectorService] which powers
/// shooting mode — separate detector instance, separate stream, separate
/// camera bindings. Only one of the two pipelines should be fed camera
/// frames at any time.
class HandDetectorService {
  HandDetectorService._();
  static final HandDetectorService instance = HandDetectorService._();

  PoseDetector? _detector;
  final StreamController<HandFrame> _handsController =
      StreamController<HandFrame>.broadcast();

  Stream<HandFrame> get handFrames => _handsController.stream;

  bool _started = false;
  bool _isProcessing = false;

  /// When false, [processCameraImage] skips inference. Toggled by the camera
  /// widget so hand tracking only runs while it's consumed (calibration +
  /// active shots), not during pause or match-over.
  bool _processingEnabled = true;

  void setProcessingEnabled(bool enabled) {
    _processingEnabled = enabled;
    if (!enabled) _isProcessing = false;
  }

  CameraDescription? _camera;
  DeviceOrientation _deviceOrientation = DeviceOrientation.portraitUp;

  static const double _minConfidence = 0.4;

  Size? lastImageSize;
  int? sensorRotationDegrees;

  bool get isFrontCamera =>
      _camera?.lensDirection == CameraLensDirection.front;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  /// Initialize the detector. Cheap to call multiple times.
  void start() {
    if (_started) return;
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        model: PoseDetectionModel.base,
        mode: PoseDetectionMode.stream,
      ),
    );
    _started = true;
    _processingEnabled = true;
    debugPrint('[HAND] detector started');
  }

  /// Release the detector. Safe to call when not started.
  Future<void> shutdown() async {
    if (!_started) return;
    _started = false;
    final det = _detector;
    _detector = null;
    await det?.close();
    debugPrint('[HAND] detector shut down');
  }

  void bindCameraSession({
    required CameraDescription camera,
    required DeviceOrientation deviceOrientation,
  }) {
    _camera = camera;
    _deviceOrientation = deviceOrientation;
  }

  /// Feed a camera frame. Skipped silently if the service is not started.
  Future<void> processCameraImage(CameraImage image) async {
    if (!_started || _camera == null) return;
    if (!_processingEnabled) return;
    if (_isProcessing) return;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) return;

    final meta = inputImage.metadata;
    if (meta != null) {
      lastImageSize = _orientedImageSize(meta.size, meta.rotation);
    }

    _isProcessing = true;
    try {
      final poses = await _detector!.processImage(inputImage);
      if (poses.isEmpty) {
        _emit(left: null, right: null);
        return;
      }
      final landmarks = poses.first.landmarks;
      _emit(
        left: _wristToNormalized(landmarks[PoseLandmarkType.leftWrist]),
        right: _wristToNormalized(landmarks[PoseLandmarkType.rightWrist]),
      );
    } catch (e) {
      debugPrint('[HAND] detection error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void _emit({Offset? left, Offset? right}) {
    if (_handsController.isClosed) return;
    _handsController.add(HandFrame(
      leftHand: left,
      rightHand: right,
      imageSize: lastImageSize,
      timestamp: DateTime.now(),
    ));
  }

  Offset? _wristToNormalized(PoseLandmark? lm) {
    if (lm == null || lm.likelihood < _minConfidence) return null;
    final size = lastImageSize;
    if (size == null) return null;

    double nx;
    double ny;
    if (lm.x > 2.0 || lm.y > 2.0) {
      nx = lm.x / size.width;
      ny = lm.y / size.height;
    } else {
      nx = lm.x;
      ny = lm.y;
    }
    if (isFrontCamera) nx = 1.0 - nx;
    return Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0));
  }

  static Size _orientedImageSize(Size buf, InputImageRotation rotation) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return Size(buf.height, buf.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return buf;
    }
  }

  InputImageRotation _rotationFromDegrees(int degrees) {
    switch (degrees) {
      case 0:
        return InputImageRotation.rotation0deg;
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
      default:
        return InputImageRotation.rotation270deg;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _camera!;
    InputImageRotation? rotation;
    int? rotationDegrees;

    if (Platform.isIOS) {
      rotationDegrees = camera.sensorOrientation;
      rotation = _rotationFromDegrees(rotationDegrees);
    } else if (Platform.isAndroid) {
      final compensation = _orientations[_deviceOrientation];
      if (compensation == null) return null;
      rotationDegrees = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + compensation) % 360
          : (camera.sensorOrientation - compensation + 360) % 360;
      rotation = _rotationFromDegrees(rotationDegrees);
    }
    if (rotation == null || rotationDegrees == null) return null;
    sensorRotationDegrees = rotationDegrees;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid) {
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
}
