import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/teams_data.dart';
import '../../models/team.dart';
import '../main_page_sound.dart';
import '../team_squad_sheet.dart';
import 'tournament_confirm_dialog.dart';

class _Pal {
  const _Pal._();
  static const bgTop = Color(0xFF24104A);
  static const bgMid = Color(0xFF170A30);
  static const bgBottom = Color(0xFF0C0620);
  static const cyan = Color(0xFF00E5FF);
  static const lime = Color(0xFFC2FF1F);
  static const green = Color(0xFF1FE07A);
}

void _tap() {
  MainPageSound.playButtonClick();
  HapticFeedback.selectionClick();
}

/// Pick one standard team to represent the player in the global cup.
class TournamentTeamPickScreen extends StatefulWidget {
  const TournamentTeamPickScreen({
    super.key,
    required this.onTeamSelected,
    required this.onBack,
  });

  final void Function(Team team) onTeamSelected;
  final VoidCallback onBack;

  @override
  State<TournamentTeamPickScreen> createState() =>
      _TournamentTeamPickScreenState();
}

class _TournamentTeamPickScreenState extends State<TournamentTeamPickScreen> {
  Team? _selected;

  Future<void> _showSquad(Team team) async {
    _tap();
    await TeamSquadSheet.show(
      context,
      team: team,
      onPickTeam: () {
        Navigator.of(context).pop();
        setState(() => _selected = team);
      },
    );
  }

  Future<void> _confirmEnter() async {
    final team = _selected;
    if (team == null) return;
    final confirmed = await showTournamentConfirmDialog(
      context,
      title: 'Enter Tournament?',
      message:
          'Play as ${team.name} in the global cup? You cannot change teams once the tournament starts.',
      confirmLabel: 'Enter',
    );
    if (confirmed && mounted) widget.onTeamSelected(team);
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
            final crossAxisCount = constraints.maxWidth > 520 ? 4 : 2;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _tap();
                          widget.onBack();
                        },
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: 2),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'GLOBAL CUP',
                            style: TextStyle(
                              color: _Pal.lime.withValues(alpha: 0.95),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.4,
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Choose Your Nation',
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '16 nations enter the knockout cup. Special teams are not eligible.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: kStandardTeams.length,
                    itemBuilder: (context, i) {
                      final team = kStandardTeams[i];
                      final selected =
                          _selected != null && teamsMatch(team, _selected!);
                      return _TeamTile(
                        team: team,
                        selected: selected,
                        onTap: () {
                          _tap();
                          setState(() => _selected = team);
                        },
                        onInfo: () => _showSquad(team),
                      );
                    },
                  ),
                ),
                _EnterBar(
                  ready: _selected != null,
                  onEnter: _selected == null ? null : _confirmEnter,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.selected,
    required this.onTap,
    required this.onInfo,
  });

  final Team team;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(
            color: selected ? _Pal.cyan : Colors.white.withValues(alpha: 0.14),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _Pal.cyan.withValues(alpha: 0.4),
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
            if (selected)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _Pal.cyan,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'YOU',
                    style: TextStyle(
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

class _EnterBar extends StatelessWidget {
  const _EnterBar({required this.ready, required this.onEnter});

  final bool ready;
  final Future<void> Function()? onEnter;

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
                ? const LinearGradient(colors: [_Pal.green, _Pal.cyan])
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
              onTap: ready
                  ? () {
                      _tap();
                      onEnter!();
                    }
                  : null,
              child: Center(
                child: Text(
                  ready ? 'ENTER TOURNAMENT' : 'Select your nation',
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
