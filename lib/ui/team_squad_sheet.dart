import 'dart:ui';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/team.dart';
import 'main_page_sound.dart';

class _Pal {
  const _Pal._();
  static const cyan = Color(0xFF00E5FF);
  static const magenta = Color(0xFFFF2ECC);
  static const lime = Color(0xFFC2FF1F);
  static const green = Color(0xFF1FE07A);
  static const orange = Color(0xFFFF6B00);
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Bottom sheet showing a full squad: shooters + keeper with stat bars.
class TeamSquadSheet extends StatelessWidget {
  const TeamSquadSheet({
    super.key,
    required this.team,
    this.onPickUser,
    this.onPickOpponent,
    this.onPickTeam,
  });

  final Team team;
  final VoidCallback? onPickUser;
  final VoidCallback? onPickOpponent;
  final VoidCallback? onPickTeam;

  static Future<void> show(
    BuildContext context, {
    required Team team,
    VoidCallback? onPickUser,
    VoidCallback? onPickOpponent,
    VoidCallback? onPickTeam,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => TeamSquadSheet(
        team: team,
        onPickUser: onPickUser,
        onPickOpponent: onPickOpponent,
        onPickTeam: onPickTeam,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    final showDualPick = onPickUser != null && onPickOpponent != null;
    final showSinglePick = onPickTeam != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        0,
        14,
        MediaQuery.paddingOf(context).bottom + 14,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF1A0B33).withValues(alpha: 0.96),
                    const Color(0xFF0C0620).withValues(alpha: 0.96),
                  ],
                ),
                border: Border.all(
                  color: _Pal.cyan.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        _Flag(
                          countryCode: team.countryCode,
                          width: 52,
                          height: 35,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                team.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Text(
                                'TEAM OVERALL ${team.overall}',
                                style: TextStyle(
                                  color: _Pal.lime.withValues(alpha: 0.9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      shrinkWrap: true,
                      children: [
                        _sectionLabel('SHOOTERS'),
                        const SizedBox(height: 8),
                        for (final p in team.shooters) _ShooterRow(player: p),
                        const SizedBox(height: 14),
                        _sectionLabel('GOALKEEPER'),
                        const SizedBox(height: 8),
                        _KeeperRow(keeper: team.keeper),
                      ],
                    ),
                  ),
                  if (showDualPick || showSinglePick) ...[
                    const Divider(height: 1, color: Colors.white24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                      child: showDualPick
                          ? Row(
                              children: [
                                Expanded(
                                  child: _SheetButton(
                                    label: 'Pick as Your Team',
                                    color: _Pal.cyan,
                                    onTap: onPickUser!,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SheetButton(
                                    label: 'Pick as Opponent',
                                    color: _Pal.orange,
                                    onTap: onPickOpponent!,
                                  ),
                                ),
                              ],
                            )
                          : _SheetButton(
                              label: 'Select This Team',
                              color: _Pal.cyan,
                              onTap: onPickTeam!,
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      );
}

class _Flag extends StatelessWidget {
  const _Flag({
    required this.countryCode,
    required this.width,
    required this.height,
  });

  final String countryCode;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: CountryFlag.fromCountryCode(
          countryCode,
          theme: ImageTheme(width: width, height: height),
        ),
      ),
    );
  }
}

class _ShooterRow extends StatelessWidget {
  const _ShooterRow({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _OvrPill(value: player.overall),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                  child: _StatBar(
                      label: 'POW', value: player.power, color: _Pal.magenta)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatBar(
                      label: 'ACC', value: player.accuracy, color: _Pal.cyan)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatBar(
                      label: 'CUR', value: player.curve, color: _Pal.lime)),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeeperRow extends StatelessWidget {
  const _KeeperRow({required this.keeper});
  final GoalkeeperRating keeper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_handball_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                keeper.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _OvrPill(value: keeper.overall),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
                child: _StatBar(
                    label: 'REF', value: keeper.reflex, color: _Pal.green)),
            const SizedBox(width: 8),
            Expanded(
                child: _StatBar(
                    label: 'PRE',
                    value: keeper.prediction,
                    color: _Pal.cyan)),
            const Spacer(),
          ],
        ),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  const _StatBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$value',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _OvrPill extends StatelessWidget {
  const _OvrPill({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Pal.lime.withValues(alpha: 0.5)),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          _tap();
          onTap();
        },
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: color.withValues(alpha: 0.16),
            border: Border.all(color: color.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
