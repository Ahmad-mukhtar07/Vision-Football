import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

import '../../data/teams_data.dart';
import '../../models/team.dart';
import '../../tournament/tournament_models.dart';

class _Pal {
  const _Pal._();
  static const cyan = Color(0xFF00E5FF);
  static const lime = Color(0xFFC2FF1F);
  static const green = Color(0xFF1FE07A);
  static const gold = Color(0xFFFFD700);
}

const _roundOrder = <TournamentRound>[
  TournamentRound.roundOf16,
  TournamentRound.quarterFinal,
  TournamentRound.semiFinal,
  TournamentRound.finalMatch,
];

enum _RoundTabVisual { active, completed, available, future }

/// Tabbed knockout bracket — one round at a time, champion slot pinned below.
class TournamentBracketView extends StatefulWidget {
  const TournamentBracketView({
    super.key,
    required this.bracket,
  });

  final TournamentBracket bracket;

  @override
  State<TournamentBracketView> createState() => _TournamentBracketViewState();
}

class _TournamentBracketViewState extends State<TournamentBracketView> {
  late TournamentRound _selectedRound;

  @override
  void initState() {
    super.initState();
    _selectedRound = widget.bracket.currentRound;
  }

  @override
  void didUpdateWidget(covariant TournamentBracketView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bracket.currentRound != widget.bracket.currentRound) {
      _selectedRound = widget.bracket.currentRound;
    }
  }

  int _teamsRemaining(TournamentBracket bracket) {
    if (bracket.champion != null) return 1;
    var remaining = 16;
    for (final round in _roundOrder) {
      if (bracket.isRoundComplete(round)) {
        remaining ~/= 2;
      } else {
        break;
      }
    }
    return remaining;
  }

  double _tournamentProgress(TournamentBracket bracket) {
    if (bracket.champion != null) return 1.0;
    var completedRounds = 0;
    for (final round in _roundOrder) {
      if (bracket.isRoundComplete(round)) {
        completedRounds++;
      } else {
        break;
      }
    }
    final fixtures = bracket.fixturesFor(bracket.currentRound);
    final roundFraction = fixtures.isEmpty
        ? 0.0
        : fixtures.where((f) => f.isPlayed).length / fixtures.length;
    return ((completedRounds + roundFraction) / _roundOrder.length)
        .clamp(0.0, 0.99);
  }

  _RoundTabVisual _tabVisual(TournamentRound round) {
    if (round == _selectedRound) return _RoundTabVisual.active;
    if (widget.bracket.isRoundComplete(round)) {
      return _RoundTabVisual.completed;
    }
    if (!_isRoundReachable(round)) return _RoundTabVisual.future;
    return _RoundTabVisual.available;
  }

  bool _isRoundReachable(TournamentRound round) {
    if (round == TournamentRound.roundOf16) return true;
    final index = _roundOrder.indexOf(round);
    final prev = _roundOrder[index - 1];
    if (widget.bracket.isRoundComplete(prev)) return true;
    return widget.bracket
        .fixturesFor(round)
        .any((f) => f.teamA != null || f.teamB != null);
  }

  String _shortTabLabel(TournamentRound round) {
    switch (round) {
      case TournamentRound.roundOf16:
        return 'R16';
      case TournamentRound.quarterFinal:
        return 'QF';
      case TournamentRound.semiFinal:
        return 'SF';
      case TournamentRound.finalMatch:
        return 'Final';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bracket = widget.bracket;
    final remaining = _teamsRemaining(bracket);
    final progress = _tournamentProgress(bracket);
    final fixtures = bracket.fixturesFor(_selectedRound);
    final useGrid = _selectedRound == TournamentRound.roundOf16 ||
        _selectedRound == TournamentRound.quarterFinal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'KNOCKOUT CUP',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$remaining teams remain',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _roundOrder.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final round = _roundOrder[i];
              return _RoundTab(
                label: _shortTabLabel(round),
                visual: _tabVisual(round),
                isCurrentRound: round == bracket.currentRound,
                onTap: () {
                  if (!_isRoundReachable(round) &&
                      !widget.bracket.isRoundComplete(round)) {
                    return;
                  }
                  setState(() => _selectedRound = round);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ProgressStrip(progress: progress),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: useGrid
                ? _MatchGrid(
                    fixtures: fixtures,
                    userTeam: bracket.userTeam,
                  )
                : _MatchList(
                    fixtures: fixtures,
                    userTeam: bracket.userTeam,
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: _ChampionCard(bracket: bracket),
        ),
      ],
    );
  }
}

class _RoundTab extends StatelessWidget {
  const _RoundTab({
    required this.label,
    required this.visual,
    required this.isCurrentRound,
    required this.onTap,
  });

  final String label;
  final _RoundTabVisual visual;
  final bool isCurrentRound;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color border;
    final Color text;

    switch (visual) {
      case _RoundTabVisual.active:
        bg = _Pal.cyan.withValues(alpha: 0.18);
        border = _Pal.cyan;
        text = _Pal.cyan;
      case _RoundTabVisual.completed:
        bg = _Pal.green.withValues(alpha: 0.12);
        border = _Pal.green.withValues(alpha: 0.55);
        text = _Pal.green.withValues(alpha: 0.9);
      case _RoundTabVisual.available:
        bg = Colors.white.withValues(alpha: 0.05);
        border = Colors.white.withValues(alpha: 0.14);
        text = Colors.white.withValues(alpha: 0.72);
      case _RoundTabVisual.future:
        bg = Colors.white.withValues(alpha: 0.04);
        border = Colors.white.withValues(alpha: 0.1);
        text = Colors.white.withValues(alpha: 0.35);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: bg,
            border: Border.all(color: border, width: visual == _RoundTabVisual.active ? 1.8 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: text,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              if (isCurrentRound && visual != _RoundTabVisual.future) ...[
                const SizedBox(width: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: visual == _RoundTabVisual.active
                        ? _Pal.lime
                        : _Pal.green,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: Colors.white.withValues(alpha: 0.1)),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_Pal.green, _Pal.cyan],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _Pal.cyan.withValues(alpha: 0.45),
                        blurRadius: 6,
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

class _MatchGrid extends StatelessWidget {
  const _MatchGrid({
    required this.fixtures,
    required this.userTeam,
  });

  final List<TournamentFixture> fixtures;
  final Team userTeam;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.92,
      ),
      itemCount: fixtures.length,
      itemBuilder: (context, i) => _MatchCard(
        fixture: fixtures[i],
        userTeam: userTeam,
        compact: true,
      ),
    );
  }
}

class _MatchList extends StatelessWidget {
  const _MatchList({
    required this.fixtures,
    required this.userTeam,
  });

  final List<TournamentFixture> fixtures;
  final Team userTeam;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < fixtures.length; i++) ...[
          _MatchCard(
            fixture: fixtures[i],
            userTeam: userTeam,
            compact: false,
          ),
          if (i < fixtures.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _MatchCard extends StatelessWidget {
  const _MatchCard({
    required this.fixture,
    required this.userTeam,
    required this.compact,
  });

  final TournamentFixture fixture;
  final Team userTeam;
  final bool compact;

  bool get _isUserNext => fixture.isUserFixture && !fixture.isPlayed;

  bool get _userWon =>
      fixture.isPlayed &&
      fixture.winner != null &&
      teamsMatch(fixture.winner!, userTeam);

  bool get _userLost =>
      fixture.isUserFixture &&
      fixture.isPlayed &&
      fixture.winner != null &&
      !teamsMatch(fixture.winner!, userTeam);

  @override
  Widget build(BuildContext context) {
    final borderColor = _isUserNext
        ? _Pal.cyan
        : Colors.white.withValues(alpha: 0.14);
    final borderWidth = _isUserNext ? 2.0 : 1.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: _isUserNext
            ? [
                BoxShadow(
                  color: _Pal.cyan.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isUserNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _Pal.cyan.withValues(alpha: 0.14),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
              ),
              child: Text(
                'YOUR MATCH',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _Pal.cyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 14,
              _isUserNext ? 8 : (compact ? 10 : 12),
              compact ? 10 : 14,
              compact ? 10 : 12,
            ),
            child: Column(
              children: [
                _TeamRow(
                  team: fixture.teamA,
                  score: fixture.scoreA,
                  isWinner: fixture.winner != null &&
                      fixture.teamA != null &&
                      teamsMatch(fixture.winner!, fixture.teamA!),
                  isLoser: fixture.winner != null &&
                      fixture.teamA != null &&
                      !teamsMatch(fixture.winner!, fixture.teamA!),
                  isUserTeam: fixture.teamA != null &&
                      teamsMatch(fixture.teamA!, userTeam),
                  isPlayed: fixture.isPlayed,
                  compact: compact,
                  emphasize: _rowEmphasis(isTeamA: true),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 4 : 6),
                  child: Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                _TeamRow(
                  team: fixture.teamB,
                  score: fixture.scoreB,
                  isWinner: fixture.winner != null &&
                      fixture.teamB != null &&
                      teamsMatch(fixture.winner!, fixture.teamB!),
                  isLoser: fixture.winner != null &&
                      fixture.teamB != null &&
                      !teamsMatch(fixture.winner!, fixture.teamB!),
                  isUserTeam: fixture.teamB != null &&
                      teamsMatch(fixture.teamB!, userTeam),
                  isPlayed: fixture.isPlayed,
                  compact: compact,
                  emphasize: _rowEmphasis(isTeamA: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _rowEmphasis({required bool isTeamA}) {
    if (!fixture.isPlayed) return false;
    if (_isUserNext) return false;
    if (fixture.isUserFixture) {
      final userSide = fixture.userIsTeamA ? isTeamA : !isTeamA;
      if (_userWon) return userSide;
      if (_userLost) return !userSide;
    }
    final team = isTeamA ? fixture.teamA : fixture.teamB;
    return fixture.winner != null &&
        team != null &&
        teamsMatch(fixture.winner!, team);
  }
}

class _TeamRow extends StatelessWidget {
  const _TeamRow({
    required this.team,
    required this.score,
    required this.isWinner,
    required this.isLoser,
    required this.isUserTeam,
    required this.isPlayed,
    required this.compact,
    required this.emphasize,
  });

  final Team? team;
  final int? score;
  final bool isWinner;
  final bool isLoser;
  final bool isUserTeam;
  final bool isPlayed;
  final bool compact;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final flagSize = compact ? 28.0 : 34.0;
    final nameOpacity = !isPlayed
        ? 0.85
        : isLoser
            ? 0.32
            : emphasize
                ? 1.0
                : 0.85;
    final scoreColor = isPlayed && isWinner
        ? _Pal.cyan
        : isPlayed
            ? Colors.white.withValues(alpha: isLoser ? 0.3 : 0.7)
            : Colors.white.withValues(alpha: 0.45);

    return Row(
      children: [
        if (team != null)
          _FlagBubble(
            team: team!,
            size: flagSize,
            isUser: isUserTeam,
            dimmed: isLoser,
          )
        else
          Container(
            width: flagSize,
            height: flagSize * 0.66,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: Text(
            team?.name ?? 'TBD',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: nameOpacity),
              fontSize: compact ? 11 : 14,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          isPlayed && score != null ? '$score' : '—',
          style: TextStyle(
            color: scoreColor,
            fontSize: compact ? 14 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _FlagBubble extends StatelessWidget {
  const _FlagBubble({
    required this.team,
    required this.size,
    required this.isUser,
    required this.dimmed,
  });

  final Team team;
  final double size;
  final bool isUser;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final border = isUser
        ? _Pal.cyan
        : Colors.white.withValues(alpha: dimmed ? 0.12 : 0.22);

    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border, width: isUser ? 1.8 : 1),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CountryFlag.fromCountryCode(
            team.countryCode,
            theme: ImageTheme(width: size, height: size * 0.66),
          ),
        ),
      ),
    );
  }
}

class _ChampionCard extends StatelessWidget {
  const _ChampionCard({required this.bracket});

  final TournamentBracket bracket;

  @override
  Widget build(BuildContext context) {
    final champion = bracket.champion;
    final complete = champion != null;
    final userWon = bracket.userWonTournament;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: complete
              ? _Pal.gold.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.14),
          width: complete ? 1.8 : 1,
        ),
        boxShadow: complete
            ? [
                BoxShadow(
                  color: _Pal.gold.withValues(alpha: 0.25),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: complete
                ? _Pal.gold
                : Colors.white.withValues(alpha: 0.35),
            size: 32,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complete ? 'CHAMPION' : 'CHAMPION',
                  style: TextStyle(
                    color: complete
                        ? _Pal.gold
                        : Colors.white.withValues(alpha: 0.45),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  complete ? champion.name : 'To be decided',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: complete
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.55),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                if (complete && userWon)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'You won the cup!',
                      style: TextStyle(
                        color: _Pal.green.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (complete)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CountryFlag.fromCountryCode(
                champion.countryCode,
                theme: const ImageTheme(width: 48, height: 32),
              ),
            ),
        ],
      ),
    );
  }
}
