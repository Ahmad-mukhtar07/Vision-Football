import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kicking_foot.dart';
import '../pose/kick_detection_config.dart';
import '../pose/kick_detector.dart';
import '../pose/player_calibration.dart';
import '../pose/pose_detector_service.dart';
import 'pose_coordinate_mapper.dart';

/// Full-screen camera preview with pose landmark overlay (ankles / lower legs).
class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({
    super.key,
    required this.cameras,
    required this.kickDetector,
    required this.calibration,
    this.kickingFoot,
    this.showPreview = true,
  });

  final List<CameraDescription> cameras;
  final KickDetector kickDetector;
  final PlayerCalibration calibration;
  final KickingFoot? kickingFoot;

  /// When false, camera stream keeps running for pose/ML Kit but preview is hidden.
  final bool showPreview;

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  static const double _minLikelihood = KickDetectionConfig.minAnkleConfidence;

  CameraController? _controller;
  int? _selectedCameraIndex;
  List<PoseLandmark> _landmarks = [];
  StreamSubscription<List<PoseLandmark>>? _poseSubscription;
  StreamSubscription? _kickSubscription;
  Timer? _kickFlashTimer;
  bool _kickFlashActive = false;
  Offset? _smoothedAnkleNorm;
  KickingFoot? _smoothedFoot;

  static const double _overlaySmoothAlpha = 0.38;
  static const double _overlayMaxJump = 0.07;

  PoseDetectorService get _poseService => PoseDetectorService.instance;
  KickDetector get _kickDetector => widget.kickDetector;

  @override
  void initState() {
    super.initState();
    _poseSubscription = _poseService.poseLandmarks.listen((landmarks) {
      if (!mounted) return;
      final imageSize = _poseService.lastImageSize;
      if (imageSize != null) {
        _kickDetector.updateImageSize(imageSize);
        widget.calibration.updateImageSize(imageSize);
      }
      _updateSmoothedAnkle(landmarks, imageSize);
      setState(() => _landmarks = landmarks);
    });
    _kickSubscription = _kickDetector.kickStream.listen((event) {
      _kickFlashTimer?.cancel();
      if (!mounted) return;
      setState(() => _kickFlashActive = true);
      _kickFlashTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _kickFlashActive = false);
      });
    });
    _initCamera();
  }

  void _updateSmoothedAnkle(List<PoseLandmark> landmarks, Size? imageSize) {
    final foot = widget.kickingFoot;
    if (foot == null || imageSize == null) {
      _smoothedAnkleNorm = null;
      _smoothedFoot = null;
      return;
    }

    if (_smoothedFoot != foot) {
      _smoothedFoot = foot;
      _smoothedAnkleNorm = null;
    }

    final byType = {for (final l in landmarks) l.type: l};
    final ankle = foot.isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    if (ankle == null || ankle.likelihood < _minLikelihood) {
      return;
    }

    final raw = Offset(
      ankle.x / imageSize.width,
      ankle.y / imageSize.height,
    );
    final ref = _smoothedAnkleNorm;
    if (ref != null && (raw - ref).distance > _overlayMaxJump) {
      return;
    }

    _smoothedAnkleNorm = ref == null
        ? raw
        : Offset(
            ref.dx + (raw.dx - ref.dx) * _overlaySmoothAlpha,
            ref.dy + (raw.dy - ref.dy) * _overlaySmoothAlpha,
          );
  }

  Future<void> _initCamera() async {
    final frontIndex = widget.cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );
    _selectedCameraIndex = frontIndex >= 0 ? frontIndex : 0;

    final camera = widget.cameras[_selectedCameraIndex!];
    debugPrint(
      '[CAMERA] front camera index=$_selectedCameraIndex '
      'lens=${camera.lensDirection.name} sensorOrientation=${camera.sensorOrientation}',
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: false,
      // ML Kit on Android expects NV21 (single plane), not YUV420 multi-plane.
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    await controller.lockCaptureOrientation(DeviceOrientation.landscapeLeft);

    await controller.startImageStream(_onCameraImage);
    if (!mounted) {
      await controller.dispose();
      return;
    }

    setState(() => _controller = controller);
  }

  void _onCameraImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return;

    _poseService.bindCameraSession(
      camera: widget.cameras[_selectedCameraIndex!],
      deviceOrientation: controller.value.deviceOrientation,
    );
    unawaited(_poseService.processCameraImage(image));
  }

  @override
  void dispose() {
    _poseSubscription?.cancel();
    _kickSubscription?.cancel();
    _kickFlashTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final imageSize = _poseService.lastImageSize;
    final rotation = _poseService.lastRotation;
    final camera = widget.cameras[_selectedCameraIndex!];

    if (!widget.showPreview) {
      return const SizedBox.expand();
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _LandscapeCameraPreview(controller: controller),
          if (imageSize != null && rotation != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = constraints.biggest;
                final mapper = PoseCoordinateMapper(
                  imageSize: imageSize,
                  rotation: rotation,
                  lensDirection: camera.lensDirection,
                );
                return CustomPaint(
                  painter: _PoseOverlayPainter(
                    landmarks: _landmarks,
                    mapper: mapper,
                    minLikelihood: _minLikelihood,
                    kickFlashActive: _kickFlashActive,
                    kickingFoot: widget.kickingFoot,
                    smoothedAnkleNorm: _smoothedAnkleNorm,
                  ),
                  size: screenSize,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Full-screen cover fit for landscape (sensor buffer is usually portrait).
class _LandscapeCameraPreview extends StatelessWidget {
  const _LandscapeCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

class _PoseOverlayPainter extends CustomPainter {
  _PoseOverlayPainter({
    required this.landmarks,
    required this.mapper,
    required this.minLikelihood,
    required this.kickFlashActive,
    required this.kickingFoot,
    required this.smoothedAnkleNorm,
  });

  final List<PoseLandmark> landmarks;
  final PoseCoordinateMapper mapper;
  final double minLikelihood;
  final bool kickFlashActive;
  final KickingFoot? kickingFoot;
  final Offset? smoothedAnkleNorm;

  @override
  void paint(Canvas canvas, Size size) {
    final byType = {for (final l in landmarks) l.type: l};

    if (kickingFoot == null) return;

    final isLeft = kickingFoot!.isLeft;
    final ankle = isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];
    final anklePt = smoothedAnkleNorm != null
        ? mapper.normalizedOffsetToScreen(smoothedAnkleNorm!, size)
        : ankle != null && ankle.likelihood >= minLikelihood
            ? mapper.normalizedToScreen(ankle, size)
            : null;
    if (anklePt == null) return;
    final fill = kickFlashActive ? Colors.greenAccent : Colors.orangeAccent;
    const radius = 18.0;

    canvas.drawCircle(anklePt, radius, Paint()..color = fill);
    canvas.drawCircle(
      anklePt,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PoseOverlayPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.mapper.imageSize != mapper.imageSize ||
        oldDelegate.kickFlashActive != kickFlashActive ||
        oldDelegate.kickingFoot != kickingFoot ||
        oldDelegate.smoothedAnkleNorm != smoothedAnkleNorm;
  }
}
