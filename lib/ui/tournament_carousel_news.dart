import 'dart:math';

import '../tournament/tournament_models.dart';

/// Builds short tournament headlines for the home carousel from real results.
class TournamentCarouselNews {
  TournamentCarouselNews._();

  static const _fallbackHeadlines = <String>[
    'Your Global Cup campaign is live!',
    'The road to glory continues.',
    'Every match writes history.',
  ];

  static String pickRandomHeadline(TournamentBracket bracket, {Random? random}) {
    final rng = random ?? Random();
    final headlines = buildHeadlines(bracket);
    if (headlines.isEmpty) {
      return _fallbackHeadlines[rng.nextInt(_fallbackHeadlines.length)];
    }
    return headlines[rng.nextInt(headlines.length)];
  }

  static List<String> buildHeadlines(TournamentBracket bracket) {
    final lines = <String>[];

    for (final round in TournamentRound.values) {
      for (final fixture in bracket.fixturesFor(round)) {
        lines.addAll(_headlinesForFixture(fixture, round));
      }
    }

    if (bracket.userEliminated) {
      lines.add('${bracket.userTeam.name} exits the Global Cup early!');
      lines.add('${bracket.userTeam.name} faces early loss.');
      lines.add(
        'Fans call for the removal of match referee after '
        "${bracket.userTeam.name}'s controversial defeat.",
      );
    }

    if (bracket.userWonTournament) {
      lines.add('${bracket.userTeam.name} qualifies for the next round!');
      lines.add(
        'Fans erupt in joy as ${bracket.userTeam.name} qualifies for the next round!',
      );
    }

    return lines.toSet().toList();
  }

  static List<String> _headlinesForFixture(
    TournamentFixture fixture,
    TournamentRound round,
  ) {
    final teamA = fixture.teamA;
    final teamB = fixture.teamB;
    if (teamA == null || teamB == null || !fixture.isPlayed) return const [];

    final scoreA = fixture.scoreA!;
    final scoreB = fixture.scoreB!;
    final lines = <String>[];

    if (scoreA == scoreB) {
      lines.add('${teamA.name} and ${teamB.name} match ends in a draw!');
      return lines;
    }

    final winner = scoreA > scoreB ? teamA : teamB;
    final loser = scoreA > scoreB ? teamB : teamA;
    final diff = (scoreA - scoreB).abs();

    if (diff == 1) {
      lines.add('${winner.name} defeats ${loser.name} in a nail biting match.');
      lines.add('${winner.name} comes from behind to defeat ${loser.name}.');
    } else {
      lines.add('${loser.name} overpowered by ${winner.name} in a thriller.');
      lines.add('In a thrilling match, ${winner.name} overpowers ${loser.name}!');
    }

    if (round != TournamentRound.groupStage) {
      lines.add('${loser.name} exits the global cup early!');
      lines.add('${loser.name} faces early loss.');
      lines.add('${winner.name} qualifies for the next round!');
      lines.add(
        'Fans erupt in joy as ${winner.name} qualifies for the next round!',
      );
      lines.add(
        'Fans call for the removal of match referee after '
        "${loser.name}'s controversial defeat.",
      );
    }

    return lines;
  }
}
