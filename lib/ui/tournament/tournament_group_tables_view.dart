import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../data/teams_data.dart';
import '../../models/team.dart';
import '../../tournament/tournament_group_standings.dart';
import '../../tournament/tournament_models.dart';

class _Pal {
  const _Pal._();
  static const cyan = Color(0xFF00E5FF);
  static const green = Color(0xFF1FE07A);
}

/// All group standings stacked vertically on one scrollable page.
class TournamentGroupTablesView extends StatelessWidget {
  const TournamentGroupTablesView({
    super.key,
    required this.bracket,
  });

  final TournamentBracket bracket;

  bool get _showQualifiers =>
      bracket.isRoundComplete(TournamentRound.groupStage);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_showQualifiers) ...[
          _QualificationBanner(),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < bracket.groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _GroupTableCard(
            group: bracket.groups[i],
            standings: TournamentGroupStandings.forGroupIndex(bracket, i),
            userTeam: bracket.userTeam,
            isUserGroup: bracket.groups[i].index == bracket.userGroup.index,
            showQualifiers: _showQualifiers,
          ),
        ],
      ],
    );
  }
}

class _QualificationBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _Pal.green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Pal.green.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: _Pal.green.withValues(alpha: 0.9),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Top two teams per group (marked Q) advance to the quarter-finals.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTableCard extends StatelessWidget {
  const _GroupTableCard({
    required this.group,
    required this.standings,
    required this.userTeam,
    required this.isUserGroup,
    required this.showQualifiers,
  });

  final TournamentGroup group;
  final List<GroupStanding> standings;
  final Team userTeam;
  final bool isUserGroup;
  final bool showQualifiers;

  @override
  Widget build(BuildContext context) {
    final borderColor = isUserGroup
        ? _Pal.cyan
        : Colors.white.withValues(alpha: 0.14);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: borderColor,
          width: isUserGroup ? 2 : 1,
        ),
        boxShadow: isUserGroup
            ? [
                BoxShadow(
                  color: _Pal.cyan.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              group.label.toUpperCase(),
              style: TextStyle(
                color: isUserGroup ? _Pal.cyan : Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ),
          _GroupTableHeader(showQualifiers: showQualifiers),
          for (var i = 0; i < standings.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 12,
                endIndent: 12,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _GroupTableRow(
                rank: i + 1,
                standing: standings[i],
                isUserTeam: teamsMatch(standings[i].team, userTeam),
                isQualified: showQualifiers && i < 2,
              ),
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _GroupTableHeader extends StatelessWidget {
  const _GroupTableHeader({required this.showQualifiers});

  final bool showQualifiers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: showQualifiers ? 34 : 22),
          Expanded(
            child: Text(
              'Team',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
          for (final label in ['MP', 'W', 'D', 'L', 'GD', 'Pts']) ...[
            SizedBox(
              width: label == 'Pts' ? 34 : 28,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  fontWeight: label == 'Pts' ? FontWeight.w900 : FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupTableRow extends StatelessWidget {
  const _GroupTableRow({
    required this.rank,
    required this.standing,
    required this.isUserTeam,
    required this.isQualified,
  });

  final int rank;
  final GroupStanding standing;
  final bool isUserTeam;
  final bool isQualified;

  @override
  Widget build(BuildContext context) {
    final accent = isUserTeam ? _Pal.cyan : Colors.white;
    final gd = standing.goalDifference;
    final gdText = gd > 0 ? '+$gd' : '$gd';
    final rowColor = isQualified
        ? _Pal.green.withValues(alpha: 0.08)
        : Colors.transparent;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: rowColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: isQualified ? 34 : 22,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$rank',
                    style: TextStyle(
                      color: accent.withValues(alpha: isUserTeam ? 1 : 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isQualified) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: _Pal.green.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _Pal.green.withValues(alpha: 0.55),
                        ),
                      ),
                      child: const Text(
                        'Q',
                        style: TextStyle(
                          color: _Pal.green,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: CountryFlag.fromCountryCode(
                standing.team.countryCode,
                theme: const ImageTheme(width: 28, height: 18),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                standing.team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isQualified
                      ? _Pal.green.withValues(alpha: isUserTeam ? 1 : 0.95)
                      : accent.withValues(alpha: isUserTeam ? 1 : 0.88),
                  fontSize: 13,
                  fontWeight: isUserTeam || isQualified
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
            ),
            _StatCell('${standing.played}'),
            _StatCell('${standing.won}'),
            _StatCell('${standing.drawn}'),
            _StatCell('${standing.lost}'),
            _StatCell(gdText),
            _StatCell('${standing.points}', bold: true),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell(this.value, {this.bold = false});

  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: bold ? 34 : 28,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: bold ? 0.95 : 0.82),
          fontSize: bold ? 13 : 12,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }
}
