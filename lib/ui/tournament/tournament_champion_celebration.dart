import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/team.dart';
import '../game_play_sound.dart';
import '../main_page_sound.dart';

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Full-screen celebration shown when the user wins the Global Cup final,
/// before the match score summary.
class TournamentChampionCelebration extends StatefulWidget {
  const TournamentChampionCelebration({
    super.key,
    required this.userTeam,
    required this.onContinue,
  });

  final Team userTeam;
  final VoidCallback onContinue;

  @override
  State<TournamentChampionCelebration> createState() =>
      _TournamentChampionCelebrationState();
}

class _TournamentChampionCelebrationState
    extends State<TournamentChampionCelebration>
    with SingleTickerProviderStateMixin {
  static const _bgTop = Color(0xFF24104A);
  static const _bgMid = Color(0xFF170A30);
  static const _bgBottom = Color(0xFF0C0620);
  static const _gold = Color(0xFFFFD54F);
  static const _lime = Color(0xFFC2FF1F);
  static const _cyan = Color(0xFF00E5FF);
  static const _magenta = Color(0xFFFF2ECC);

  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;
  late final List<_GlitterSpark> _glitter;

  @override
  void initState() {
    super.initState();
    GamePlaySound.playGoalCheer();

    final rng = math.Random(42);
    _pieces = List.generate(72, (i) {
      return _ConfettiPiece(
        x: rng.nextDouble(),
        y: -0.15 - rng.nextDouble() * 0.35,
        speed: 0.22 + rng.nextDouble() * 0.38,
        wobble: rng.nextDouble() * math.pi * 2,
        spin: (rng.nextDouble() - 0.5) * 6,
        size: 6 + rng.nextDouble() * 8,
        color: [
          _gold,
          _lime,
          _cyan,
          _magenta,
          Colors.white,
        ][i % 5],
      );
    });
    _glitter = List.generate(36, (i) {
      return _GlitterSpark(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        phase: rng.nextDouble() * math.pi * 2,
        size: 1.5 + rng.nextDouble() * 2.5,
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_bgTop, _bgMid, _bgBottom],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _CelebrationPainter(
                  elapsed: _controller.value * 4,
                  pieces: _pieces,
                  glitter: _glitter,
                ),
                size: Size.infinite,
              );
            },
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.85,
                colors: [
                  _gold.withValues(alpha: 0.28),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _TrophyBadge(animation: _controller),
                  const SizedBox(height: 28),
                  Text(
                    'GLOBAL CUP',
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'CHAMPIONS!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1.2,
                      shadows: [
                        Shadow(color: _gold, blurRadius: 24),
                        Shadow(color: _cyan, blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.userTeam.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(27),
                        gradient: const LinearGradient(
                          colors: [_gold, _lime],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _gold.withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(27),
                          onTap: () {
                            _tap();
                            widget.onContinue();
                          },
                          child: const Center(
                            child: Text(
                              'VIEW RESULT',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
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

class _TrophyBadge extends StatelessWidget {
  const _TrophyBadge({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final pulse = 1.0 + math.sin(animation.value * math.pi * 2) * 0.06;
        final glow = 18 + math.sin(animation.value * math.pi * 2) * 8;
        return Transform.scale(
          scale: pulse,
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFD54F).withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD54F).withValues(alpha: 0.55),
                  blurRadius: glow,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: const Color(0xFFFFD54F), width: 2),
        ),
        child: const Icon(
          Icons.emoji_events_rounded,
          size: 64,
          color: Color(0xFFFFD54F),
        ),
      ),
    );
  }
}

class _ConfettiPiece {
  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.speed,
    required this.wobble,
    required this.spin,
    required this.size,
    required this.color,
  });

  final double x;
  final double y;
  final double speed;
  final double wobble;
  final double spin;
  final double size;
  final Color color;
}

class _GlitterSpark {
  _GlitterSpark({
    required this.x,
    required this.y,
    required this.phase,
    required this.size,
  });

  final double x;
  final double y;
  final double phase;
  final double size;
}

class _CelebrationPainter extends CustomPainter {
  _CelebrationPainter({
    required this.elapsed,
    required this.pieces,
    required this.glitter,
  });

  final double elapsed;
  final List<_ConfettiPiece> pieces;
  final List<_GlitterSpark> glitter;

  @override
  void paint(Canvas canvas, Size size) {
    for (final spark in glitter) {
      final twinkle = (math.sin(elapsed * 4 + spark.phase) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 + twinkle * 0.55);
      canvas.drawCircle(
        Offset(spark.x * size.width, spark.y * size.height),
        spark.size * (0.7 + twinkle * 0.6),
        paint,
      );
    }

    for (final piece in pieces) {
      final drift = math.sin(elapsed * 2.4 + piece.wobble) * 0.04;
      final y = ((piece.y + elapsed * piece.speed) % 1.4) - 0.2;
      final center = Offset(
        (piece.x + drift).clamp(0.0, 1.0) * size.width,
        y * size.height,
      );
      final rotation = elapsed * piece.spin;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: piece.size,
        height: piece.size * 0.55,
      );
      canvas.drawRect(
        rect,
        Paint()..color = piece.color.withValues(alpha: 0.92),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) =>
      oldDelegate.elapsed != elapsed;
}
