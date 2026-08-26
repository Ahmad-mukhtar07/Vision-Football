import 'dart:async';
import 'dart:math' as math;

import 'package:app_settings/app_settings.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/game_settings.dart';
import 'data/testing_profile.dart';
import 'data/user_profile_store.dart';
import 'keeper/keeper_screen.dart';
import 'ui/full_match_screen.dart';
import 'ui/mode_selection_overlay.dart';
import 'ui/tournament/tournament_screen.dart';
import 'ui/onboarding/onboarding_profile_screen.dart';
import 'ui/tutorial/keeping_tutorial_screen.dart';
import 'ui/tutorial/kicking_tutorial_screen.dart';
import 'ui/vision_football_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameSettings.load();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
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

/// The sequential first-run steps shown before the main menu on a fresh
/// install: profile setup, then the kicking and keeping tutorials.
enum _OnboardingStep { profile, kickingTutorial, keepingTutorial }

/// Starts the camera pipeline or shows a permission/settings fallback.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static const _loadingMinDuration = Duration(milliseconds: 2200);

  List<CameraDescription>? _cameras;
  bool _cameraFailed = false;
  bool _loadingComplete = false;
  GameMode? _selectedMode;

  /// Non-null only during the first-run flow; cleared once onboarding is done.
  _OnboardingStep? _onboardingStep;

  @override
  void initState() {
    super.initState();
    _runBootstrap();
  }

  Future<void> _runBootstrap() async {
    // Match-art loading screen — start camera init now and keep the screen
    // visible for at least the loading-strip animation so it never flashes.
    final loadingStart = DateTime.now();
    await _startCameraPipeline();
    final profile = await UserProfileStore.load();
    await TestingProfile.applyOnStartup(profile.displayName);
    final onboardingComplete = await UserProfileStore.isOnboardingComplete();
    final elapsed = DateTime.now().difference(loadingStart);
    final remaining = _loadingMinDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    if (!mounted) return;
    setState(() {
      _loadingComplete = true;
      if (!onboardingComplete) _onboardingStep = _OnboardingStep.profile;
    });
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
      setState(() => _cameras = cameras);
    } on CameraException catch (e) {
      debugPrint('Camera startup failed: ${e.code} ${e.description}');
      if (!mounted) return;
      setState(() => _cameraFailed = true);
    } catch (e, st) {
      debugPrint('Camera startup failed: $e\n$st');
      if (!mounted) return;
      setState(() => _cameraFailed = true);
    }
  }

  void _onModeSelected(GameMode mode) {
    setState(() => _selectedMode = mode);
  }

  void _returnToMainMenu() {
    setState(() => _selectedMode = null);
  }

  Future<void> _finishOnboarding() async {
    await UserProfileStore.markOnboardingComplete();
    if (!mounted) return;
    setState(() => _onboardingStep = null);
  }

  /// Builds the current first-run step. Reached only after the camera pipeline
  /// is ready, so [_cameras] is guaranteed non-null here.
  Widget _buildOnboarding() {
    switch (_onboardingStep!) {
      case _OnboardingStep.profile:
        return OnboardingProfileScreen(
          onComplete: () => setState(
            () => _onboardingStep = _OnboardingStep.kickingTutorial,
          ),
        );
      case _OnboardingStep.kickingTutorial:
        return KickingTutorialScreen(
          cameras: _cameras!,
          onReturnToMenu: () => setState(
            () => _onboardingStep = _OnboardingStep.keepingTutorial,
          ),
        );
      case _OnboardingStep.keepingTutorial:
        return KeepingTutorialScreen(
          cameras: _cameras!,
          onReturnToMenu: _finishOnboarding,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_cameraFailed) {
      body = const CameraPermissionRequiredScreen();
    } else if (!_loadingComplete || _cameras == null) {
      body = const _LoadingScreen();
    } else if (_onboardingStep != null) {
      body = _buildOnboarding();
    } else if (_selectedMode == null) {
      body = ModeSelectionOverlay(onModeSelected: _onModeSelected);
    } else if (_selectedMode == GameMode.fullMatch) {
      body = FullMatchScreen(
        cameras: _cameras!,
        onReturnToMenu: _returnToMainMenu,
      );
    } else if (_selectedMode == GameMode.tournament) {
      body = TournamentScreen(
        cameras: _cameras!,
        onReturnToMenu: _returnToMainMenu,
      );
    } else if (_selectedMode == GameMode.takeShots) {
      body = VisionFootballScreen(
        cameras: _cameras!,
        onReturnToMenu: _returnToMainMenu,
      );
    } else if (_selectedMode == GameMode.kickingTutorial) {
      body = KickingTutorialScreen(
        cameras: _cameras!,
        onReturnToMenu: _returnToMainMenu,
      );
    } else if (_selectedMode == GameMode.keepingTutorial) {
      body = KeepingTutorialScreen(
        cameras: _cameras!,
        onReturnToMenu: _returnToMainMenu,
      );
    } else {
      body = KeeperScreen(
        cameras: _cameras!,
        onReturnToMenu: _returnToMainMenu,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      // Keep the home screen layout fixed when a bottom-sheet field opens
      // the keyboard — the sheet handles its own inset instead.
      resizeToAvoidBottomInset: false,
      body: body,
    );
  }
}

/// Initialization screen: hero art + animated loading strip while the camera
/// initializes.
class _LoadingScreen extends StatefulWidget {
  const _LoadingScreen();

  @override
  State<_LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<_LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const _heroArt = 'assets/images/main_page/match_art.png';
  static const _cyan = Color(0xFF00E5FF);
  static const _green = Color(0xFF1FE07A);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heroSize = math.min(
              constraints.maxWidth * 0.92,
              constraints.maxHeight * 0.66,
            );
            final barWidth = math.min(constraints.maxWidth * 0.66, 320.0);

            return Column(
              children: [
                // Hero art fills the upper region, vertically centered.
                Expanded(
                  child: Center(
                    child: Image.asset(
                      _heroArt,
                      width: heroSize,
                      height: heroSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
                // Loading strip sits lower on the screen.
                SizedBox(
                  width: barWidth,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return _LoadingStrip(
                        progress: _controller.value,
                        cyan: _cyan,
                        green: _green,
                      );
                    },
                  ),
                ),
                SizedBox(height: constraints.maxHeight * 0.12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingStrip extends StatelessWidget {
  const _LoadingStrip({
    required this.progress,
    required this.cyan,
    required this.green,
  });

  final double progress;
  final Color cyan;
  final Color green;

  @override
  Widget build(BuildContext context) {
    const trackHeight = 8.0;
    final fill = 0.12 + progress * 0.82;

    return ClipRRect(
      borderRadius: BorderRadius.circular(trackHeight),
      child: SizedBox(
        height: trackHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.12)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [green, cyan]),
                    boxShadow: [
                      BoxShadow(
                        color: cyan.withValues(alpha: 0.55),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
