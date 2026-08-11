import 'dart:ui';

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/teams_data.dart';
import '../models/team.dart';
import 'main_page_sound.dart';

/// Which selection slot a tapped team gets assigned to.
enum _SlotTarget { user, opponent }

/// Arcade palette shared with the main menu look.
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
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Quick Match team picker: choose YOUR team and the OPPONENT, preview each
/// squad's ratings, then start. Shooting mode only.
class TeamSelectionScreen extends StatefulWidget {
  const TeamSelectionScreen({
    super.key,
    required this.onStart,
    required this.onBack,
  });

  /// Called with (userTeam, opponentTeam) when the player taps Start.
  final void Function(Team userTeam, Team opponentTeam) onStart;
  final VoidCallback onBack;

  @override
  State<TeamSelectionScreen> createState() => _TeamSelectionScreenState();
}

class _TeamSelectionScreenState extends State<TeamSelectionScreen> {
  Team? _userTeam;
  Team? _opponentTeam;
  _SlotTarget _active = _SlotTarget.user;

  bool get _ready => _userTeam != null && _opponentTeam != null;

  void _assignToActiveSlot(Team team) {
    _tap();
    setState(() {
      if (_active == _SlotTarget.user) {
        _userTeam = team;
        // Auto-advance to opponent if it still needs picking.
        if (_opponentTeam == null) _active = _SlotTarget.opponent;
      } else {
        _opponentTeam = team;
        if (_userTeam == null) _active = _SlotTarget.user;
      }
    });
  }

  void _setActive(_SlotTarget target) {
    _tap();
    setState(() => _active = target);
  }

  Future<void> _start() async {
    if (!_ready) return;
    _tap();
    widget.onStart(_userTeam!, _opponentTeam!);
  }

  Future<void> _showSquad(Team team) async {
    _tap();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SquadSheet(
        team: team,
        onPickUser: () {
          Navigator.of(context).pop();
          setState(() {
            _userTeam = team;
            if (_opponentTeam == null) _active = _SlotTarget.opponent;
          });
        },
        onPickOpponent: () {
          Navigator.of(context).pop();
          setState(() {
            _opponentTeam = team;
            if (_userTeam == null) _active = _SlotTarget.user;
          });
        },
      ),
    );
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final crossAxisCount = w > 520 ? 4 : 2;

            return Column(
              children: [
                _Header(onBack: () {
                  _tap();
                  widget.onBack();
                }),
                _VersusBar(
                  userTeam: _userTeam,
                  opponentTeam: _opponentTeam,
                  active: _active,
                  onTapUser: () => _setActive(_SlotTarget.user),
                  onTapOpponent: () => _setActive(_SlotTarget.opponent),
                ),
                _PickPrompt(active: _active),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: kAllTeams.length,
                    itemBuilder: (context, i) {
                      final team = kAllTeams[i];
                      final isUser =
                          _userTeam != null && teamsMatch(team, _userTeam!);
                      final isOpp = _opponentTeam != null &&
                          teamsMatch(team, _opponentTeam!);
                      return _TeamTile(
                        team: team,
                        selectedAsUser: isUser,
                        selectedAsOpponent: isOpp,
                        onTap: () => _assignToActiveSlot(team),
                        onInfo: () => _showSquad(team),
                      );
                    },
                  ),
                ),
                _StartBar(ready: _ready, onStart: _start),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          const SizedBox(width: 2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QUICK MATCH',
                style: TextStyle(
                  color: _Pal.lime.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                'Select Teams',
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
}

/// The YOU vs OPPONENT header cards.
class _VersusBar extends StatelessWidget {
  const _VersusBar({
    required this.userTeam,
    required this.opponentTeam,
    required this.active,
    required this.onTapUser,
    required this.onTapOpponent,
  });

  final Team? userTeam;
  final Team? opponentTeam;
  final _SlotTarget active;
  final VoidCallback onTapUser;
  final VoidCallback onTapOpponent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _SlotCard(
                label: 'YOUR TEAM',
                accent: _Pal.cyan,
                team: userTeam,
                isActive: active == _SlotTarget.user,
                onTap: onTapUser,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _SlotCard(
                label: 'OPPONENT',
                accent: _Pal.orange,
                team: opponentTeam,
                isActive: active == _SlotTarget.opponent,
                onTap: onTapOpponent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.label,
    required this.accent,
    required this.team,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final Team? team;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: isActive
                ? accent
                : Colors.white.withValues(alpha: 0.18),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            if (team != null) ...[
              _Flag(countryCode: team!.countryCode, width: 54, height: 36),
              const SizedBox(height: 6),
              Text(
                team!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'OVR ${team!.overall}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              SizedBox(
                height: 36,
                child: Center(
                  child: Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap a flag',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _PickPrompt extends StatelessWidget {
  const _PickPrompt({required this.active});
  final _SlotTarget active;

  @override
  Widget build(BuildContext context) {
    final isUser = active == _SlotTarget.user;
    final accent = isUser ? _Pal.cyan : _Pal.orange;
    final text = isUser ? 'Picking: YOUR TEAM' : 'Picking: OPPONENT';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(shape: BoxShape.circle, color: accent),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.selectedAsUser,
    required this.selectedAsOpponent,
    required this.onTap,
    required this.onInfo,
  });

  final Team team;
  final bool selectedAsUser;
  final bool selectedAsOpponent;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final Color? badgeColor = selectedAsUser
        ? _Pal.cyan
        : (selectedAsOpponent ? _Pal.orange : null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: badgeColor ?? Colors.white.withValues(alpha: 0.14),
            width: badgeColor != null ? 2 : 1,
          ),
          boxShadow: badgeColor != null
              ? [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: _Flag(
                        countryCode: team.countryCode,
                        width: 66,
                        height: 44,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'OVR ${team.overall}',
                    style: TextStyle(
                      color: _Pal.lime.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Info button (squad preview).
            Positioned(
              top: 2,
              right: 2,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: onInfo,
                icon: Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                tooltip: 'View squad',
              ),
            ),
            // Selection badge (You / Opp).
            if (badgeColor != null)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedAsUser ? 'YOU' : 'OPP',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
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

class _StartBar extends StatelessWidget {
  const _StartBar({required this.ready, required this.onStart});
  final bool ready;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        12 + MediaQuery.paddingOf(context).bottom * 0.2,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: ready
                ? const LinearGradient(
                    colors: [_Pal.green, _Pal.cyan],
                  )
                : null,
            color: ready ? null : Colors.white.withValues(alpha: 0.08),
            boxShadow: ready
                ? [
                    BoxShadow(
                      color: _Pal.green.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onTap: ready ? onStart : null,
              child: Center(
                child: Text(
                  ready ? 'START MATCH' : 'Select both teams',
                  style: TextStyle(
                    color: ready
                        ? Colors.black87
                        : Colors.white.withValues(alpha: 0.5),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded flag with a graceful fallback if the code is unknown.
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

/// Bottom sheet showing a full squad: shooters + keeper with stat bars.
class _SquadSheet extends StatelessWidget {
  const _SquadSheet({
    required this.team,
    required this.onPickUser,
    required this.onPickOpponent,
  });

  final Team team;
  final VoidCallback onPickUser;
  final VoidCallback onPickOpponent;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
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
                        for (final p in team.shooters)
                          _ShooterRow(player: p),
                        const SizedBox(height: 14),
                        _sectionLabel('GOALKEEPER'),
                        const SizedBox(height: 8),
                        _KeeperRow(keeper: team.keeper),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SheetButton(
                            label: 'Pick as Your Team',
                            color: _Pal.cyan,
                            onTap: onPickUser,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SheetButton(
                            label: 'Pick as Opponent',
                            color: _Pal.orange,
                            onTap: onPickOpponent,
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
              Expanded(child: _StatBar(label: 'POW', value: player.power, color: _Pal.magenta)),
              const SizedBox(width: 8),
              Expanded(child: _StatBar(label: 'ACC', value: player.accuracy, color: _Pal.cyan)),
              const SizedBox(width: 8),
              Expanded(child: _StatBar(label: 'CUR', value: player.curve, color: _Pal.lime)),
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
            Expanded(child: _StatBar(label: 'REF', value: keeper.reflex, color: _Pal.green)),
            const SizedBox(width: 8),
            Expanded(child: _StatBar(label: 'PRE', value: keeper.prediction, color: _Pal.cyan)),
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
