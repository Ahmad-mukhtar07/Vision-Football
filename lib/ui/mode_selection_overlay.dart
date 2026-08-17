import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass_panel.dart';
import 'main_page_sound.dart';
import '../data/user_profile_store.dart';
import '../models/user_profile.dart';
import 'profile_settings_sheet.dart';

/// Selectable game mode from the start screen.
enum GameMode {
  fullMatch,
  takeShots,
  rollingBalls,
  beTheKeeper,
  kickingTutorial,
  keepingTutorial,
}

/// When false, standalone practice modes are hidden from the Full Match picker
/// (Take Shots / Be the Keeper). Routing in [main.dart] is unchanged.
const _kShowStandalonePracticeModes = true;

/// When false, the Tutorials card and kicking/keeping tutorial picker are
/// hidden from the home screen. Routing in [main.dart] is unchanged.
const _kShowTutorialModes = true;

/// Plays the main-menu click sound + light haptic for button feedback.
void _playTapFeedback() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Shared "Electric Arcade" palette — neon magenta + cyan + lime on indigo.
class _Arcade {
  const _Arcade._();

  // Background (deep indigo/purple base).
  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);

  // Neon accents.
  static const magenta = Color(0xFFFF2ECC);
  static const cyan = Color(0xFF00E5FF);
  static const lime = Color(0xFFC2FF1F);
  static const violet = Color(0xFF9B30FF);

  // Pitch green — ties the menu to the on-field gameplay.
  static const green = Color(0xFF1FE07A);
}

/// Premium modular sports dashboard — entry point for all game modes.
class ModeSelectionOverlay extends StatefulWidget {
  const ModeSelectionOverlay({
    super.key,
    required this.onModeSelected,
  });

  final ValueChanged<GameMode> onModeSelected;

  @override
  State<ModeSelectionOverlay> createState() => _ModeSelectionOverlayState();
}

class _ModeSelectionOverlayState extends State<ModeSelectionOverlay>
    with SingleTickerProviderStateMixin {
  static const _matchArt = 'assets/images/main_page/match_art.png';
  static const _tournamentArt = 'assets/images/main_page/tournament_art.png';
  static const _onlineArt = 'assets/images/main_page/online_art.jpeg';
  static const _ballArt = 'assets/images/ball/Ball-left.png';
  static const _tutorialArt = 'assets/images/tips/Tips-Shooting.png';

  static const _avatars = <String>[
    'assets/images/main_page/avatars/avatar_1.png',
    'assets/images/main_page/avatars/avatar_2.png',
    'assets/images/main_page/avatars/avatar_3.png',
    'assets/images/main_page/avatars/avatar_4.png',
  ];

  /// Single ticker drives particle drift, featured-card glow pulse, ball
  /// rotation, and streak shimmer (derived phases — no extra controllers).
  static const _masterLoopSeconds = 6.0;

  late final AnimationController _masterController;
  late final List<_ParticleSeed> _particleSeeds;
  late final String _avatarAsset;
  UserProfile _profile = UserProfile.defaults;

  @override
  void initState() {
    super.initState();
    _avatarAsset = _avatars[math.Random().nextInt(_avatars.length)];
    unawaited(_loadProfile());

    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    final rng = math.Random(7);
    _particleSeeds = List.generate(22, (i) {
      return _ParticleSeed(
        xFactor: rng.nextDouble(),
        yFactor: rng.nextDouble(),
        radius: 1.5 + rng.nextDouble(),
        speed: 0.018 + rng.nextDouble() * 0.028,
        warm: rng.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    super.dispose();
  }

  double get _elapsedSeconds => _masterController.value * _masterLoopSeconds;

  Future<void> _loadProfile() async {
    final profile = await UserProfileStore.load();
    if (mounted) setState(() => _profile = profile);
  }

  void _openProTips(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ProTipsSheet(),
    );
  }

  void _openFullMatch(BuildContext context) {
    if (!_kShowStandalonePracticeModes) {
      widget.onModeSelected(GameMode.fullMatch);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FullMatchRoleSheet(
        onModeSelected: (mode) {
          Navigator.of(ctx).pop();
          widget.onModeSelected(mode);
        },
      ),
    );
  }

  void _openTutorials(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _TutorialPickerSheet(
        onModeSelected: (mode) {
          Navigator.of(ctx).pop();
          widget.onModeSelected(mode);
        },
      ),
    );
  }

  Future<void> _openSettings(BuildContext context) async {
    final updated = await showModalBottomSheet<UserProfile>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ProfileSettingsSheet(initial: _profile),
    );
    if (updated != null && mounted) {
      setState(() => _profile = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Arcade.bgTop, _Arcade.bgMid, _Arcade.bgBottom],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Neon glow bloom behind everything.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.55),
                radius: 1.15,
                colors: [
                  Color(0x5AFF2ECC),
                  Color(0x2E00E5FF),
                  Color(0x00000000),
                ],
                stops: [0.0, 0.42, 1.0],
              ),
            ),
          ),
          const CustomPaint(
            painter: _NeonStreaksPainter(),
            size: Size.infinite,
          ),
          const CustomPaint(
            painter: _AthleticStripePainter(),
            size: Size.infinite,
          ),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _masterController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _DriftingParticlePainter(
                    elapsedSeconds: _elapsedSeconds,
                    seeds: _particleSeeds,
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileStrip(
                    avatarAsset: _avatarAsset,
                    profile: _profile,
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: _SpotlightHero(
                      onTap: () => _openProTips(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    flex: 2,
                    child: _ModeSelectorGrid(
                      matchArt: _matchArt,
                      ballArt: _ballArt,
                      tournamentArt: _tournamentArt,
                      onlineArt: _onlineArt,
                      tutorialArt: _tutorialArt,
                      masterAnimation: _masterController,
                      onFullMatchTap: () => _openFullMatch(context),
                      onTutorialsTap: () => _openTutorials(context),
                      onSettingsTap: () => _openSettings(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticleSeed {
  const _ParticleSeed({
    required this.xFactor,
    required this.yFactor,
    required this.radius,
    required this.speed,
    required this.warm,
  });

  final double xFactor;
  final double yFactor;
  final double radius;
  final double speed;
  final bool warm;
}

/// Bold neon corner slashes that echo the theme — clustered top-left and
/// bottom-right so the center stays clear for the cards.
class _NeonStreaksPainter extends CustomPainter {
  const _NeonStreaksPainter();

  void _slash(
    Canvas canvas,
    Offset start,
    double length,
    double width,
    Color color,
  ) {
    // ~58° "/" slash going up-right.
    const angle = -58 * math.pi / 180;
    final end = start +
        Offset(math.cos(angle), math.sin(angle)) * length;

    final glow = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
    final core = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = width * 0.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(start, end, glow);
    canvas.drawLine(start, end, core);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Top-left cluster.
    _slash(canvas, Offset(-30, h * 0.12), h * 0.30, 12, _Arcade.magenta);
    _slash(canvas, Offset(-12, h * 0.20), h * 0.24, 7, _Arcade.cyan);
    _slash(canvas, Offset(16, h * 0.07), h * 0.17, 5, _Arcade.lime);

    // Bottom-right cluster.
    _slash(canvas, Offset(w * 0.76, h + 30), h * 0.32, 13, _Arcade.cyan);
    _slash(canvas, Offset(w * 0.88, h + 12), h * 0.25, 8, _Arcade.magenta);
    _slash(canvas, Offset(w * 0.68, h + 22), h * 0.18, 5, _Arcade.lime);
  }

  @override
  bool shouldRepaint(covariant _NeonStreaksPainter oldDelegate) => false;
}

class _AthleticStripePainter extends CustomPainter {
  const _AthleticStripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const spacing = 28.0;
    final diagonal = size.width + size.height;
    for (var d = -diagonal; d < diagonal; d += spacing) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AthleticStripePainter oldDelegate) => false;
}

class _DriftingParticlePainter extends CustomPainter {
  _DriftingParticlePainter({
    required this.elapsedSeconds,
    required this.seeds,
  });

  final double elapsedSeconds;
  final List<_ParticleSeed> seeds;

  @override
  void paint(Canvas canvas, Size size) {
    final warmPaint = Paint()..color = _Arcade.lime.withValues(alpha: 0.22);
    final coolPaint = Paint()..color = Colors.white.withValues(alpha: 0.16);

    for (final seed in seeds) {
      final x = seed.xFactor * size.width;
      final drift = (seed.yFactor - seed.speed * elapsedSeconds) % 1.0;
      final y = (drift < 0 ? drift + 1 : drift) * size.height;
      canvas.drawCircle(
        Offset(x, y),
        seed.radius,
        seed.warm ? warmPaint : coolPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DriftingParticlePainter oldDelegate) =>
      oldDelegate.elapsedSeconds != elapsedSeconds;
}

class _ProfileStrip extends StatelessWidget {
  const _ProfileStrip({
    required this.avatarAsset,
    required this.profile,
  });

  static const _logoAsset = 'assets/images/VisionFootball-Logo-NoBG.png';
  static const _avatarSize = 44.0;
  static const _logoHeight = 54.0;

  final String avatarAsset;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final subtitle =
        '${profile.countryName.toUpperCase()}  •  ${profile.position.toUpperCase()}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: _avatarSize,
          height: _avatarSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: _Arcade.cyan, width: 2),
            boxShadow: [
              BoxShadow(
                color: _Arcade.cyan.withValues(alpha: 0.5),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              avatarAsset,
              fit: BoxFit.cover,
              // Avatar renders at 44px; decode it small to save memory on
              // low-end devices instead of keeping the full-res bitmap.
              cacheWidth: 132,
              errorBuilder: (context, error, stack) => const Icon(
                Icons.person_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                color: _Arcade.lime.withValues(alpha: 0.9),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          height: _logoHeight,
          child: Image.asset(
            _logoAsset,
            fit: BoxFit.contain,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.high,
          ),
        ),
      ],
    );
  }
}

/// Data for one tips carousel slide.
class _SpotlightSlide {
  const _SpotlightSlide({
    required this.title,
    required this.body,
    required this.backgroundAsset,
    required this.accent,
  });

  final String title;
  final String body;
  final String backgroundAsset;
  final Color accent;
}

const _proTipSlides = <_SpotlightSlide>[
  _SpotlightSlide(
    title: 'Set Up Your Shot 🎯',
    body: 'Shooting game: Place your phone at waist height for the best shooting experience.',
    backgroundAsset: 'assets/images/tips/Tips-Shooting.png',
    accent: _Arcade.green,
  ),
  _SpotlightSlide(
    title: 'Own Your Goal 🧤',
    body: 'Keeping game: Center your head in the screen before going into keeping mode.',
    backgroundAsset: 'assets/images/tips/Tips-Keeping.png',
    accent: _Arcade.cyan,
  ),
  _SpotlightSlide(
    title: 'Find Your Range 📏',
    body: 'Stand 4–6 feet from your phone for better body tracking.',
    backgroundAsset: 'assets/images/tips/Tips-Distance.png',
    accent: _Arcade.lime,
  ),
  _SpotlightSlide(
    title: 'Light It Up 💡',
    body: 'Play in a well-lit room so the camera tracks every move.',
    backgroundAsset: 'assets/images/tips/Tips-Light.png',
    accent: _Arcade.magenta,
  ),
];

/// Auto-cycling tips banner on the home screen.
class _SpotlightHero extends StatefulWidget {
  const _SpotlightHero({this.onTap});

  final VoidCallback? onTap;

  @override
  State<_SpotlightHero> createState() => _SpotlightHeroState();
}

class _SpotlightHeroState extends State<_SpotlightHero> {
  static const _slides = _proTipSlides;

  static const _interval = Duration(milliseconds: 4200);

  late final PageController _pageController;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoAdvanceTimer();
  }

  void _startAutoAdvanceTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _advanceAutomatically());
  }

  void _advanceAutomatically() {
    if (!mounted || !_pageController.hasClients) return;
    final next = (_index + 1) % _slides.length;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _startAutoAdvanceTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    const cardRadius = BorderRadius.all(Radius.circular(20));

    final carousel = AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: cardRadius,
        border: Border.all(
          color: slide.accent.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: slide.accent.withValues(alpha: 0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: cardRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: _slides.length,
              itemBuilder: (context, i) =>
                  _SpotlightSlideView(slide: _slides[i]),
            ),
            Positioned(
              left: 18,
              bottom: 12,
              child: Row(
                children: List.generate(_slides.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 6),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? slide.accent
                          : Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.onTap == null) return carousel;
    return _TapScaleCard(
      onTap: widget.onTap!,
      borderRadius: BorderRadius.circular(20),
      child: carousel,
    );
  }
}

/// Single tips carousel slide (background + copy).
class _SpotlightSlideView extends StatelessWidget {
  const _SpotlightSlideView({required this.slide});

  final _SpotlightSlide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          slide.backgroundAsset,
          fit: BoxFit.cover,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.15),
                Colors.black.withValues(alpha: 0.65),
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1A0B33).withValues(alpha: 0.35),
                slide.accent.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),
        Positioned(
          right: -20,
          top: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  slide.accent.withValues(alpha: 0.4),
                  slide.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
          child: _SlideContent(slide: slide),
        ),
      ],
    );
  }
}

class _SlideContent extends StatelessWidget {
  const _SlideContent({required this.slide});

  final _SpotlightSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRO TIP',
          style: TextStyle(
            color: slide.accent,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          slide.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          slide.body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _ModeSelectorGrid extends StatelessWidget {
  const _ModeSelectorGrid({
    required this.matchArt,
    required this.ballArt,
    required this.tournamentArt,
    required this.onlineArt,
    required this.tutorialArt,
    required this.masterAnimation,
    required this.onFullMatchTap,
    required this.onTutorialsTap,
    required this.onSettingsTap,
  });

  final String matchArt;
  final String ballArt;
  final String tournamentArt;
  final String onlineArt;
  final String tutorialArt;
  final Animation<double> masterAnimation;
  final VoidCallback onFullMatchTap;
  final VoidCallback onTutorialsTap;
  final VoidCallback onSettingsTap;

  static const double _rowGap = 14;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _FullMatchCard(
            artAsset: matchArt,
            ballArt: ballArt,
            masterAnimation: masterAnimation,
            onTap: onFullMatchTap,
          ),
        ),
        const SizedBox(height: _rowGap),
        Expanded(
          flex: 2,
          // Horizontally scrollable strip — sized so the next card peeks in.
          child: LayoutBuilder(
            builder: (context, constraints) {
              const peek = 44.0;
              final cardWidth =
                  (constraints.maxWidth - _rowGap * 2 - peek) / 2;
              return ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _LockedModeCard(
                      title: 'TOURNAMENTS',
                      artAsset: tournamentArt,
                      accent: _Arcade.lime,
                    ),
                  ),
                  const SizedBox(width: _rowGap),
                  SizedBox(
                    width: cardWidth,
                    child: _LockedModeCard(
                      title: 'ONLINE ARENA',
                      artAsset: onlineArt,
                      accent: _Arcade.cyan,
                    ),
                  ),
                  if (_kShowTutorialModes) ...[
                    const SizedBox(width: _rowGap),
                    SizedBox(
                      width: cardWidth,
                      child: _TutorialModeCard(
                        artAsset: tutorialArt,
                        onTap: onTutorialsTap,
                      ),
                    ),
                  ],
                  const SizedBox(width: _rowGap),
                  SizedBox(
                    width: cardWidth,
                    child: _SettingsModeCard(onTap: onSettingsTap),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Tappable "Tutorials" card living in the scrollable bottom strip.
class _TutorialModeCard extends StatelessWidget {
  const _TutorialModeCard({
    required this.artAsset,
    required this.onTap,
  });

  final String artAsset;
  final VoidCallback onTap;

  static const _accent = _Arcade.magenta;
  static const _cardStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
  );

  @override
  Widget build(BuildContext context) {
    return _TapScaleCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(artAsset, fit: BoxFit.cover),
            ColoredBox(
              color: const Color(0xFF0C0620).withValues(alpha: 0.55),
            ),
            ColoredBox(color: _accent.withValues(alpha: 0.16)),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
            Center(
              child: Icon(
                Icons.school_rounded,
                size: 32,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TUTORIALS',
                    textAlign: TextAlign.center,
                    style: _cardStyle.copyWith(
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Learn the basics',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tappable "Settings" card in the scrollable bottom strip.
class _SettingsModeCard extends StatelessWidget {
  const _SettingsModeCard({required this.onTap});

  final VoidCallback onTap;

  static const _accent = _Arcade.violet;
  static const _cardStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
  );

  @override
  Widget build(BuildContext context) {
    return _TapScaleCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Opaque base so the card looks identical without a (no-op)
            // backdrop blur behind it.
            const ColoredBox(color: Color(0xFF0C0620)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF1A0B33),
                    _accent.withValues(alpha: 0.35),
                    const Color(0xFF0C0620),
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _accent.withValues(alpha: 0.7),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
            Center(
              child: Icon(
                Icons.settings_rounded,
                size: 32,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SETTINGS',
                    textAlign: TextAlign.center,
                    style: _cardStyle.copyWith(
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Name & profile',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullMatchCard extends StatelessWidget {
  const _FullMatchCard({
    required this.artAsset,
    required this.ballArt,
    required this.masterAnimation,
    required this.onTap,
  });

  final String artAsset;
  final String ballArt;
  final Animation<double> masterAnimation;
  final VoidCallback onTap;

  static const _loopSeconds = 6.0;

  static const _cardStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
  );

  double _glowBlurRadius(double elapsedSeconds) {
    final phase = (elapsedSeconds % 1.8) / 1.8;
    final wave = (1 - math.cos(phase * math.pi * 2)) / 2;
    return 8 + wave * 16;
  }

  @override
  Widget build(BuildContext context) {
    // Static visuals (images, gradients, text) are built ONCE and cached in a
    // RepaintBoundary, so the per-frame animation only re-composites them
    // instead of rebuilding/re-decoding. The blurred backdrop was fully hidden
    // behind the cover image, so it has been dropped (no visual change).
    final cardBody = RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.5),
          gradient: const LinearGradient(
            colors: [_Arcade.cyan, _Arcade.magenta, _Arcade.green],
          ),
        ),
        padding: const EdgeInsets.all(1.5),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(19),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: Image.asset(
                  artAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF150826).withValues(alpha: 0.82),
                      _Arcade.violet.withValues(alpha: 0.24),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 0.85],
                  ),
                ),
              ),
              Positioned(
                right: 14,
                top: 14,
                child: _SpinningBall(animation: masterAnimation, asset: ballArt),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FEATURED MODE',
                      style: TextStyle(
                        color: _Arcade.lime,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.4,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'FULL MATCH',
                      style: _cardStyle.copyWith(
                        fontSize: 26,
                        letterSpacing: 0.6,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Shoot & save — take your team to victory',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return _TapScaleCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: masterAnimation,
          child: cardBody,
          builder: (context, child) {
            final glowBlur = _glowBlurRadius(masterAnimation.value * _loopSeconds);
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [_Arcade.magenta, _Arcade.cyan, _Arcade.green],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _Arcade.green.withValues(alpha: 0.5),
                    blurRadius: glowBlur,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: _Arcade.cyan.withValues(alpha: 0.4),
                    blurRadius: glowBlur * 0.6,
                    spreadRadius: 0,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(1.5),
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Continuously-rotating ball badge. The image decodes once and is cached as a
/// retained layer; only the rotation matrix updates per frame.
class _SpinningBall extends StatelessWidget {
  const _SpinningBall({required this.animation, required this.asset});

  final Animation<double> animation;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(
        child: Image.asset(
          asset,
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          cacheWidth: 132,
        ),
      ),
      builder: (context, child) {
        return Transform.rotate(
          angle: animation.value * 2 * math.pi,
          child: child,
        );
      },
    );
  }
}

class _LockedModeCard extends StatelessWidget {
  const _LockedModeCard({
    required this.title,
    required this.artAsset,
    required this.accent,
  });

  final String title;
  final String artAsset;
  final Color accent;

  static const _cardStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w900,
    fontStyle: FontStyle.italic,
  );

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            artAsset,
            fit: BoxFit.cover,
          ),
          ColoredBox(
            color: const Color(0xFF0C0620).withValues(alpha: 0.6),
          ),
          ColoredBox(
            color: accent.withValues(alpha: 0.16),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accent.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.lock_outline,
              size: 32,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: _cardStyle.copyWith(
                    fontSize: 13,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Coming Soon',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TapScaleCard extends StatefulWidget {
  const _TapScaleCard({
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });

  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_TapScaleCard> createState() => _TapScaleCardState();
}

class _TapScaleCardState extends State<_TapScaleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {
        _playTapFeedback();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ProTipsSheet extends StatelessWidget {
  const _ProTipsSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'PRO TIPS',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _Arcade.cyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 18),
                for (var i = 0; i < _proTipSlides.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _ProTipListTile(slide: _proTipSlides[i]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProTipListTile extends StatelessWidget {
  const _ProTipListTile({required this.slide});

  final _SpotlightSlide slide;

  @override
  Widget build(BuildContext context) {
    const tileRadius = BorderRadius.all(Radius.circular(14));

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: tileRadius,
        border: Border.all(color: slide.accent.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: slide.accent.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: tileRadius,
        child: SizedBox(
          height: 108,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                slide.backgroundAsset,
                fit: BoxFit.cover,
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.black.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PRO TIP',
                      style: TextStyle(
                        color: slide.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      slide.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        slide.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullMatchRoleSheet extends StatelessWidget {
  const _FullMatchRoleSheet({
    required this.onModeSelected,
  });

  final ValueChanged<GameMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'CHOOSE A MODE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Arcade.lime,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 18),
            _RoleButton(
              title: 'Full Match',
              subtitle: 'Pick teams, coin toss, shoot & save',
              accent: _Arcade.magenta,
              icon: Icons.emoji_events_rounded,
              onTap: () => onModeSelected(GameMode.fullMatch),
            ),
            if (_kShowStandalonePracticeModes) ...[
              const SizedBox(height: 18),
              Text(
                'PRACTICE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 12),
              _RoleButton(
                title: 'Take Shots',
                subtitle: 'Beat the keeper with your feet',
                accent: _Arcade.green,
                icon: Icons.sports_soccer_rounded,
                onTap: () => onModeSelected(GameMode.takeShots),
              ),
              const SizedBox(height: 12),
              _RoleButton(
                title: 'Timing Strike',
                subtitle: 'Kick when the ring turns green',
                accent: _Arcade.lime,
                icon: Icons.timelapse_rounded,
                onTap: () => onModeSelected(GameMode.rollingBalls),
              ),
              const SizedBox(height: 12),
              _RoleButton(
                title: 'Be the Keeper',
                subtitle: 'Save shots with your hands',
                accent: _Arcade.cyan,
                icon: Icons.back_hand_outlined,
                onTap: () => onModeSelected(GameMode.beTheKeeper),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TutorialPickerSheet extends StatelessWidget {
  const _TutorialPickerSheet({required this.onModeSelected});

  final ValueChanged<GameMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TUTORIALS',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Arcade.magenta,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 18),
            _RoleButton(
              title: 'Kicking',
              subtitle: 'Place your shots into the goal',
              accent: _Arcade.green,
              icon: Icons.sports_soccer_rounded,
              onTap: () => onModeSelected(GameMode.kickingTutorial),
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'Keeping',
              subtitle: 'Get your gloves to the ball',
              accent: _Arcade.cyan,
              icon: Icons.back_hand_outlined,
              onTap: () => onModeSelected(GameMode.keepingTutorial),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _playTapFeedback();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: accent.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: accent, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: accent.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
