import 'dart:math' as math;

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/team.dart';
import 'main_page_sound.dart';

/// The user's role in a half: taking shots, or keeping goal.
enum MatchRole { shooter, keeper }

enum _CoinFace { heads, tails }

enum _TossPhase { calling, flipping, won, lost }

class _Pal {
  const _Pal._();
  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);
  static const cyan = Color(0xFF00E5FF);
  static const magenta = Color(0xFFFF2ECC);
  static const lime = Color(0xFFC2FF1F);
  static const green = Color(0xFF1FE07A);
  static const orange = Color(0xFFFF6B00);
  static const gold = Color(0xFFFFD700);
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Coin toss: the user calls heads/tails; on a win they choose to kick or keep
/// first, on a loss the opponent's (random) choice is revealed. Outputs the
/// user's role for the FIRST half.
class CoinTossScreen extends StatefulWidget {
  const CoinTossScreen({
    super.key,
    required this.userTeam,
    required this.opponentTeam,
    required this.onDecided,
    required this.onBack,
  });

  final Team userTeam;
  final Team opponentTeam;

  /// Called with the user's role in the first half once the toss is resolved.
  final void Function(MatchRole firstHalfRole) onDecided;
  final VoidCallback onBack;

  @override
  State<CoinTossScreen> createState() => _CoinTossScreenState();
}

class _CoinTossScreenState extends State<CoinTossScreen>
    with SingleTickerProviderStateMixin {
  final math.Random _rng = math.Random();

  late final AnimationController _flip;
  _TossPhase _phase = _TossPhase.calling;
  _CoinFace? _userCall;
  _CoinFace? _result;

  /// On a loss, the role the opponent forced on the user, plus what they chose.
  MatchRole? _forcedRole;
  bool _opponentChoseToKick = false;

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _onFlipDone();
      });
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  void _call(_CoinFace face) {
    if (_phase != _TossPhase.calling) return;
    _tap();
    _userCall = face;
    _result = _rng.nextBool() ? _CoinFace.heads : _CoinFace.tails;
    setState(() => _phase = _TossPhase.flipping);
    _flip.forward(from: 0);
  }

  void _onFlipDone() {
    final won = _userCall == _result;
    if (won) {
      setState(() => _phase = _TossPhase.won);
    } else {
      // Opponent randomly elects to kick or keep first; the user gets the
      // opposite role.
      _opponentChoseToKick = _rng.nextBool();
      _forcedRole =
          _opponentChoseToKick ? MatchRole.keeper : MatchRole.shooter;
      setState(() => _phase = _TossPhase.lost);
    }
  }

  void _chooseRole(MatchRole role) {
    _tap();
    widget.onDecided(role);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Pal.bgTop, _Pal.bgMid, _Pal.bgBottom],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight - 36),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _matchupRow(),
                          _coin(),
                          _phaseContent(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              _tap();
              widget.onBack();
            },
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FULL MATCH',
                style: TextStyle(
                  color: _Pal.lime.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'Coin Toss',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matchupRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _teamChip(widget.userTeam, _Pal.cyan, 'YOU'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'VS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        _teamChip(widget.opponentTeam, _Pal.orange, 'OPP'),
      ],
    );
  }

  Widget _teamChip(Team team, Color accent, String tag) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CountryFlag.fromCountryCode(
            team.countryCode,
            theme: const ImageTheme(width: 50, height: 33),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          team.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          tag,
          style: TextStyle(
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _coin() {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        // Several full rotations during the flip; settles flat at rest.
        final spinning = _phase == _TossPhase.flipping;
        final angle = spinning ? _flip.value * math.pi * 2 * 5 : 0.0;
        final lift = spinning ? math.sin(_flip.value * math.pi) * 30 : 0.0;
        // A flipping coin alternately shows its edge — fake that by squashing
        // the disc and hiding the face when it's near side-on.
        final faceVisible = math.cos(angle).abs() > 0.32;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, -lift),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015)
                  ..rotateX(angle),
                child: SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            center: Alignment(-0.3, -0.4),
                            colors: [
                              Color(0xFFFFF7C8),
                              _Pal.gold,
                              Color(0xFFA9760A),
                            ],
                            stops: [0.0, 0.58, 1.0],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _Pal.gold.withValues(alpha: 0.5),
                              blurRadius: 26,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const SizedBox(width: 132, height: 132),
                      ),
                      const CustomPaint(
                        size: Size(132, 132),
                        painter: _CoinEdgePainter(),
                      ),
                      // Inner minted disc.
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFFEFA6), Color(0xFFE2A938)],
                            stops: [0.0, 1.0],
                          ),
                          border: Border.all(
                            color: const Color(0xFF8A6508).withValues(alpha: 0.7),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Opacity(
                            opacity: faceVisible ? 1 : 0,
                            child: _coinFace(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The embossed content stamped on the coin for the current phase.
  Widget _coinFace() {
    const inkColor = Color(0xFF5A4500);

    switch (_phase) {
      case _TossPhase.calling:
        return const Text(
          '?',
          style: TextStyle(
            color: inkColor,
            fontSize: 52,
            fontWeight: FontWeight.w900,
          ),
        );
      case _TossPhase.flipping:
        return const SizedBox.shrink();
      case _TossPhase.won:
      case _TossPhase.lost:
        final heads = _result == _CoinFace.heads;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              heads ? Icons.sports_soccer_rounded : Icons.shield_rounded,
              color: inkColor,
              size: 40,
            ),
            const SizedBox(height: 2),
            Text(
              heads ? 'HEADS' : 'TAILS',
              style: const TextStyle(
                color: inkColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ],
        );
    }
  }

  Widget _phaseContent() {
    switch (_phase) {
      case _TossPhase.calling:
        return Column(
          children: [
            const Text(
              'Call it!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    'HEADS',
                    _Pal.cyan,
                    () => _call(_CoinFace.heads),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _bigButton(
                    'TAILS',
                    _Pal.magenta,
                    () => _call(_CoinFace.tails),
                  ),
                ),
              ],
            ),
          ],
        );
      case _TossPhase.flipping:
        return Text(
          'You called ${_userCall == _CoinFace.heads ? 'HEADS' : 'TAILS'}…',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        );
      case _TossPhase.won:
        return Column(
          children: [
            const Text(
              'You won the toss!',
              style: TextStyle(
                color: _Pal.green,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose what to do first',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _bigButton(
                    'KICK FIRST',
                    _Pal.green,
                    () => _chooseRole(MatchRole.shooter),
                    icon: Icons.sports_soccer_rounded,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _bigButton(
                    'KEEP FIRST',
                    _Pal.cyan,
                    () => _chooseRole(MatchRole.keeper),
                    icon: Icons.back_hand_outlined,
                  ),
                ),
              ],
            ),
          ],
        );
      case _TossPhase.lost:
        final youKickFirst = _forcedRole == MatchRole.shooter;
        return Column(
          children: [
            const Text(
              'You lost the toss',
              style: TextStyle(
                color: _Pal.orange,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.opponentTeam.name} chose to '
              '${_opponentChoseToKick ? 'KICK' : 'KEEP'} first.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You'll ${youKickFirst ? 'KICK' : 'KEEP'} first.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _Pal.lime.withValues(alpha: 0.95),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            _bigButton(
              'CONTINUE',
              _Pal.green,
              () => _chooseRole(_forcedRole!),
              icon: Icons.play_arrow_rounded,
            ),
          ],
        );
    }
  }

  Widget _bigButton(
    String label,
    Color color,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.65)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.black87, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the milled ridges around a coin's rim so it reads as minted metal
/// rather than a flat disc.
class _CoinEdgePainter extends CustomPainter {
  const _CoinEdgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = const Color(0xFF8A6508).withValues(alpha: 0.55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const ticks = 54;
    for (var i = 0; i < ticks; i++) {
      final a = (i / ticks) * 2 * math.pi;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(
        center + dir * (radius - 10),
        center + dir * (radius - 4),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoinEdgePainter oldDelegate) => false;
}
