import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hand_detector_service.dart';

/// Camera capture used by goalkeeper mode.
///
/// Owns the camera controller and forwards every frame to
/// [HandDetectorService]. The preview itself is invisible — only the
/// detection stream is needed by the keeper scene.
class KeeperCameraPreview extends StatefulWidget {
  const KeeperCameraPreview({
    super.key,
    required this.cameras,
  });

  final List<CameraDescription> cameras;

  @override
  State<KeeperCameraPreview> createState() => _KeeperCameraPreviewState();
}

class _KeeperCameraPreviewState extends State<KeeperCameraPreview> {
  CameraController? _controller;
  int? _selectedCameraIndex;
  HandDetectorService get _handService => HandDetectorService.instance;

  @override
  void initState() {
    super.initState();
    _handService.start();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final frontIndex = widget.cameras.indexWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );
    _selectedCameraIndex = frontIndex >= 0 ? frontIndex : 0;
    final camera = widget.cameras[_selectedCameraIndex!];

    final controller = CameraController(
      camera,
      ResolutionPreset.medium,
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
    await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

    _handService.bindCameraSession(
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
    _handService.bindCameraSession(
      camera: widget.cameras[_selectedCameraIndex!],
      deviceOrientation: controller.value.deviceOrientation,
    );
    unawaited(_handService.processCameraImage(image));
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    unawaited(_handService.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The keeper scene is drawn by Flame; we don't render the camera preview.
    return const SizedBox.expand();
  }
}
