import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/kicking_foot.dart';
import '../pose/kick_detection_config.dart';
import '../pose/kick_detector.dart';
import '../pose/player_calibration.dart';
import '../pose/pose_detector_service.dart';
import 'pose_coordinate_mapper.dart';

/// Camera stream for pose/ML Kit; preview optional (hidden during match).
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
  int? _sensorRotationDegrees;
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

  /// Raw sensor orientation from [CameraDescription] (degrees).
  int? get sensorRotationDegrees => _sensorRotationDegrees;

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

    final isFront = widget.cameras[_selectedCameraIndex ?? 0].lensDirection ==
        CameraLensDirection.front;
    final raw = PoseCoordinateMapper.landmarkToNormalized(
      landmark: ankle,
      imageSize: imageSize,
      isFrontCamera: isFront,
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
    _sensorRotationDegrees = camera.sensorOrientation;

    debugPrint(
      '[CAMERA] front camera index=$_selectedCameraIndex '
      'lens=${camera.lensDirection.name} sensorOrientation=${camera.sensorOrientation}',
    );

    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }

    debugPrint(
      '[CAM] deviceOrientation=${controller.value.deviceOrientation} '
      'sensorOrientation=${camera.sensorOrientation}',
    );

    await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

    _poseService.bindCameraSession(
      camera: camera,
      deviceOrientation: controller.value.deviceOrientation,
    );

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
    final camera = widget.cameras[_selectedCameraIndex!];
    final sensor = _sensorRotationDegrees ?? camera.sensorOrientation;

    if (!widget.showPreview) {
      return const SizedBox.expand();
    }

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _PortraitCameraPreview(controller: controller),
          if (imageSize != null)
            LayoutBuilder(
              builder: (context, constraints) {
                final screenSize = constraints.biggest;
                final mapper = PoseCoordinateMapper(
                  imageSize: imageSize,
                  screenSize: screenSize,
                  isFrontCamera:
                      camera.lensDirection == CameraLensDirection.front,
                  sensorRotation: sensor,
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

/// Full-screen cover fit for portrait.
class _PortraitCameraPreview extends StatelessWidget {
  const _PortraitCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize?.width ?? 1,
          height: controller.value.previewSize?.height ?? 1,
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
    if (kickingFoot == null) return;

    final byType = {for (final l in landmarks) l.type: l};
    final isLeft = kickingFoot!.isLeft;
    final ankle = isLeft
        ? byType[PoseLandmarkType.leftAnkle]
        : byType[PoseLandmarkType.rightAnkle];

    final anklePt = smoothedAnkleNorm != null
        ? mapper.normalizedOffsetToScreen(smoothedAnkleNorm!)
        : ankle != null && ankle.likelihood >= minLikelihood
            ? mapper.toScreen(ankle)
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
