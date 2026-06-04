import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'hand_detector_service.dart';
import 'keeper_preview_layout.dart';

/// Camera capture used by goalkeeper mode.
///
/// Owns the camera controller and forwards every frame to
/// [HandDetectorService]. The preview itself is invisible — only the
/// detection stream is needed by the keeper scene.
class KeeperCameraPreview extends StatefulWidget {
  const KeeperCameraPreview({
    super.key,
    required this.cameras,
    this.showPreview = false,
  });

  final List<CameraDescription> cameras;

  /// When true the live camera feed is shown in a centered box (calibration).
  /// When false only the detection pipeline runs — nothing is drawn.
  final bool showPreview;

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

    final previewSize = ctrl.value.previewSize;
    if (previewSize == null) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = constraints.biggest;
        final portraitSize =
            KeeperPreviewLayout.orientedPreviewSize(previewSize);
        final rect = KeeperPreviewLayout.calibrationRect(screen, portraitSize);

        return ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: previewSize.width,
                            height: previewSize.height,
                            child: CameraPreview(ctrl),
                          ),
                        ),
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: _UpperBodyOutlineOverlay(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Draws the upper-body outline PNG over the camera using [BlendMode.lighten]
/// so black pixels pass through and only the golden lines are visible.
class _UpperBodyOutlineOverlay extends StatefulWidget {
  const _UpperBodyOutlineOverlay();

  static const _asset = 'assets/images/outlines/upperbody-outline.png';

  @override
  State<_UpperBodyOutlineOverlay> createState() =>
      _UpperBodyOutlineOverlayState();
}

class _UpperBodyOutlineOverlayState extends State<_UpperBodyOutlineOverlay> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load(_UpperBodyOutlineOverlay._asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    if (mounted) setState(() => _image = frame.image);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const SizedBox.shrink();
    return CustomPaint(
      painter: _UpperBodyOutlinePainter(image),
      size: Size.infinite,
    );
  }
}

class _UpperBodyOutlinePainter extends CustomPainter {
  _UpperBodyOutlinePainter(this.image);

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final scale = math.min(size.width / src.width, size.height / src.height);
    final dst = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: src.width * scale,
      height: src.height * scale,
    );

    final paint = Paint()
      ..blendMode = BlendMode.lighten
      ..filterQuality = FilterQuality.medium;

    canvas.drawImageRect(image, src, dst, paint);
  }

  @override
  bool shouldRepaint(covariant _UpperBodyOutlinePainter oldDelegate) =>
      oldDelegate.image != image;
}
