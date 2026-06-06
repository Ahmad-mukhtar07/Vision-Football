import 'dart:ui';

import 'package:flutter/material.dart';

import 'glass_panel.dart';

/// Selectable game mode from the start screen.
enum GameMode { takeShots, beTheKeeper }

/// Premium modular sports dashboard — entry point for all game modes.
class ModeSelectionOverlay extends StatelessWidget {
  const ModeSelectionOverlay({
    super.key,
    required this.onModeSelected,
  });

  final ValueChanged<GameMode> onModeSelected;

  static const _slateBlack = Color(0xFF0B0E14);
  static const _hyperCyan = Color(0xFF00E5FF);
  static const _voltGreen = Color(0xFF7CFF7C);

  static const _stadiumBg = 'assets/images/main_page/stadium_bg.jpeg';
  static const _matchArt = 'assets/images/main_page/match_art.png';
  static const _tournamentArt = 'assets/images/main_page/tournament_art.png';
  static const _onlineArt = 'assets/images/main_page/online_art.jpeg';

  void _openFullMatch(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _FullMatchRoleSheet(
        onModeSelected: (mode) {
          Navigator.of(ctx).pop();
          onModeSelected(mode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _slateBlack,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _DashboardHeader(),
              const SizedBox(height: 20),
              const Expanded(
                child: _PlayerDashboardCard(
                  stadiumAsset: ModeSelectionOverlay._stadiumBg,
                  hyperCyan: ModeSelectionOverlay._hyperCyan,
                  voltGreen: ModeSelectionOverlay._voltGreen,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                flex: 2,
                child: _ModeSelectorGrid(
                  matchArt: _matchArt,
                  tournamentArt: _tournamentArt,
                  onlineArt: _onlineArt,
                  voltGreen: _voltGreen,
                  hyperCyan: _hyperCyan,
                  onFullMatchTap: () => _openFullMatch(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'VISION FOOTBALL',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w800,
        letterSpacing: 4.2,
      ),
    );
  }
}

class _PlayerDashboardCard extends StatelessWidget {
  const _PlayerDashboardCard({
    required this.stadiumAsset,
    required this.hyperCyan,
    required this.voltGreen,
  });

  final String stadiumAsset;
  final Color hyperCyan;
  final Color voltGreen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: Image.asset(
                stadiumAsset,
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
                    Colors.black.withValues(alpha: 0.52),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.12),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(
                          color: hyperCyan.withValues(alpha: 0.55),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.person_rounded,
                        size: 34,
                        color: hyperCyan.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Striker10',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: voltGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: voltGreen.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              '7 Day Streak 🔥',
                              style: TextStyle(
                                color: voltGreen,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
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
          ],
        ),
      ),
    );
  }
}

class _ModeSelectorGrid extends StatelessWidget {
  const _ModeSelectorGrid({
    required this.matchArt,
    required this.tournamentArt,
    required this.onlineArt,
    required this.voltGreen,
    required this.hyperCyan,
    required this.onFullMatchTap,
  });

  final String matchArt;
  final String tournamentArt;
  final String onlineArt;
  final Color voltGreen;
  final Color hyperCyan;
  final VoidCallback onFullMatchTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: _FullMatchCard(
            artAsset: matchArt,
            voltGreen: voltGreen,
            onTap: onFullMatchTap,
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          flex: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _LockedModeCard(
                  title: 'TOURNAMENTS',
                  artAsset: tournamentArt,
                  hyperCyan: hyperCyan,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _LockedModeCard(
                  title: 'ONLINE ARENA',
                  artAsset: onlineArt,
                  hyperCyan: hyperCyan,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FullMatchCard extends StatelessWidget {
  const _FullMatchCard({
    required this.artAsset,
    required this.voltGreen,
    required this.onTap,
  });

  final String artAsset;
  final Color voltGreen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: voltGreen.withValues(alpha: 0.65),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: voltGreen.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                          Colors.black.withValues(alpha: 0.78),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 0.85],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FEATURED MODE',
                          style: TextStyle(
                            color: voltGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'FULL MATCH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Shoot & save — pick your role',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
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
        ),
      ),
    );
  }
}

class _LockedModeCard extends StatelessWidget {
  const _LockedModeCard({
    required this.title,
    required this.artAsset,
    required this.hyperCyan,
  });

  final String title;
  final String artAsset;
  final Color hyperCyan;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              artAsset,
              fit: BoxFit.cover,
            ),
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.62),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ),
            Center(
              child: Icon(
                Icons.lock_outline,
                size: 32,
                color: Colors.white.withValues(alpha: 0.75),
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Coming Soon',
                    style: TextStyle(
                      color: hyperCyan.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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

class _FullMatchRoleSheet extends StatelessWidget {
  const _FullMatchRoleSheet({
    required this.onModeSelected,
  });

  final ValueChanged<GameMode> onModeSelected;

  static const _hyperCyan = Color(0xFF00E5FF);
  static const _voltGreen = Color(0xFF7CFF7C);

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
              'CHOOSE YOUR ROLE',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _hyperCyan,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Full Match',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 18),
            _RoleButton(
              title: 'Take Shots',
              subtitle: 'Beat the keeper with your feet',
              accent: _voltGreen,
              icon: Icons.sports_soccer_rounded,
              onTap: () => onModeSelected(GameMode.takeShots),
            ),
            const SizedBox(height: 12),
            _RoleButton(
              title: 'Be the Keeper',
              subtitle: 'Save shots with your hands',
              accent: _hyperCyan,
              icon: Icons.back_hand_outlined,
              onTap: () => onModeSelected(GameMode.beTheKeeper),
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
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
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
