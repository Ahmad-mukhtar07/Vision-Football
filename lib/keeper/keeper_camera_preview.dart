import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ui/fullscreen_camera_preview.dart';
import 'hand_detector_service.dart';

/// Camera capture used by goalkeeper mode.
///
/// Owns the camera controller and forwards every frame to
/// [HandDetectorService]. During calibration the feed is fullscreen;
/// otherwise only the detection pipeline runs.
class KeeperCameraPreview extends StatefulWidget {
  const KeeperCameraPreview({
    super.key,
    required this.cameras,
    this.showPreview = false,
    this.active = true,
  });

  final List<CameraDescription> cameras;

  /// When true the live camera feed fills the screen (calibration).
  /// When false only the detection pipeline runs — nothing is drawn.
  final bool showPreview;

  /// When false the image stream and hand inference are stopped (pause,
  /// match-over). The controller stays initialized for a cheap resume; active
  /// shot/calibration phases keep this true, so tracking is unchanged there.
  final bool active;

  @override
  State<KeeperCameraPreview> createState() => _KeeperCameraPreviewState();
}

class _KeeperCameraPreviewState extends State<KeeperCameraPreview> {
  CameraController? _controller;
  int? _selectedCameraIndex;
  bool _streaming = false;
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
    _handService.setProcessingEnabled(widget.active);
    if (widget.active) {
      _streaming = true;
      await controller.startImageStream(_onCameraImage);
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void didUpdateWidget(covariant KeeperCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      unawaited(_applyActive());
    }
  }

  Future<void> _applyActive() async {
    final controller = _controller;
    _handService.setProcessingEnabled(widget.active);
    if (controller == null || !controller.value.isInitialized) return;
    try {
      if (widget.active && !_streaming) {
        _streaming = true;
        await controller.startImageStream(_onCameraImage);
      } else if (!widget.active && _streaming) {
        _streaming = false;
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('[KEEPER CAM] stream toggle failed: $e');
    }
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
    if (_streaming) {
      _streaming = false;
      unawaited(_controller?.stopImageStream());
    }
    _controller?.dispose();
    unawaited(_handService.shutdown());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showPreview) {
      return const SizedBox.expand();
    }

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    return FullscreenCameraPreview(controller: ctrl);
  }
}
