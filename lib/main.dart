import 'package:app_settings/app_settings.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/vision_football_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const VisionFootballApp());
}

class VisionFootballApp extends StatelessWidget {
  const VisionFootballApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AppBootstrap(),
    );
  }
}

/// Starts the camera pipeline or shows a permission/settings fallback.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  Widget _body = const _LoadingScreen();

  @override
  void initState() {
    super.initState();
    _startCameraPipeline();
  }

  Future<void> _startCameraPipeline() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('no_camera', 'No cameras available');
      }

      final frontIndex = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final selectedIndex = frontIndex >= 0 ? frontIndex : 0;
      final camera = cameras[selectedIndex];

      final probe = CameraController(
        camera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      await probe.initialize();
      await probe.dispose();

      debugPrint(
        '[CAMERA] selected index=$selectedIndex '
        'lens=${camera.lensDirection.name} id=${camera.name}',
      );

      if (!mounted) return;
      setState(() {
        _body = VisionFootballScreen(cameras: cameras);
      });
    } on CameraException catch (e) {
      debugPrint('Camera startup failed: ${e.code} ${e.description}');
      if (!mounted) return;
      setState(() => _body = const CameraPermissionRequiredScreen());
    } catch (e, st) {
      debugPrint('Camera startup failed: $e\n$st');
      if (!mounted) return;
      setState(() => _body = const CameraPermissionRequiredScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _body,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Vision Football — Initializing',
        style: TextStyle(color: Colors.white, fontSize: 20),
      ),
    );
  }
}

class CameraPermissionRequiredScreen extends StatelessWidget {
  const CameraPermissionRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Camera permission required',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => AppSettings.openAppSettings(),
              child: const Text('Open app settings'),
            ),
          ],
        ),
      ),
    );
  }
}
