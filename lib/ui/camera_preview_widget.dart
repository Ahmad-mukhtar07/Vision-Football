import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose/pose_detector_service.dart';
import 'pose_coordinate_mapper.dart';

/// Full-screen camera preview with pose landmark overlay (ankles / lower legs).
class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({
    super.key,
    required this.cameras,
  });

  final List<CameraDescription> cameras;

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  static const double _minLikelihood = 0.6;

  CameraController? _controller;
  int? _selectedCameraIndex;
  List<PoseLandmark> _landmarks = [];
  StreamSubscription<List<PoseLandmark>>? _poseSubscription;

  PoseDetectorService get _poseService => PoseDetectorService.instance;

  @override
  void initState() {
    super.initState();
    _poseSubscription = _poseService.poseLandmarks.listen((landmarks) {
      if (!mounted) return;
      setState(() => _landmarks = landmarks);
    });
    _initCamera();
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

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(controller),
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

class _PoseOverlayPainter extends CustomPainter {
  _PoseOverlayPainter({
    required this.landmarks,
    required this.mapper,
    required this.minLikelihood,
  });

  final List<PoseLandmark> landmarks;
  final PoseCoordinateMapper mapper;
  final double minLikelihood;

  @override
  void paint(Canvas canvas, Size size) {
    final byType = {for (final l in landmarks) l.type: l};

    final leftKnee = byType[PoseLandmarkType.leftKnee];
    final leftAnkle = byType[PoseLandmarkType.leftAnkle];
    final rightKnee = byType[PoseLandmarkType.rightKnee];
    final rightAnkle = byType[PoseLandmarkType.rightAnkle];

    final linePaint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final dotStroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    void drawLeg(
      PoseLandmark? knee,
      PoseLandmark? ankle,
    ) {
      if (knee != null &&
          ankle != null &&
          knee.likelihood >= minLikelihood &&
          ankle.likelihood >= minLikelihood) {
        final kneePt = mapper.normalizedToScreen(knee, size);
        final anklePt = mapper.normalizedToScreen(ankle, size);
        canvas.drawLine(kneePt, anklePt, linePaint);
        _drawAnkleDot(canvas, anklePt, dotPaint, dotStroke);
      } else if (ankle != null && ankle.likelihood >= minLikelihood) {
        _drawAnkleDot(
          canvas,
          mapper.normalizedToScreen(ankle, size),
          dotPaint,
          dotStroke,
        );
      }
    }

    drawLeg(leftKnee, leftAnkle);
    drawLeg(rightKnee, rightAnkle);
  }

  void _drawAnkleDot(
    Canvas canvas,
    Offset center,
    Paint fill,
    Paint stroke,
  ) {
    const radius = 14.0;
    canvas.drawCircle(center, radius, fill);
    canvas.drawCircle(center, radius, stroke);
  }

  @override
  bool shouldRepaint(covariant _PoseOverlayPainter oldDelegate) {
    return oldDelegate.landmarks != landmarks ||
        oldDelegate.mapper.imageSize != mapper.imageSize;
  }
}
