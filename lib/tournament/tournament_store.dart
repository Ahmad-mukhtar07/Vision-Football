import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/teams_data.dart';
import '../models/team.dart';
import 'tournament_models.dart';

/// Persists an in-progress knockout cup between app sessions.
class TournamentStore {
  TournamentStore._();

  static const _key = 'tournament_save_v2';

  static Future<bool> hasSavedTournament() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<void> save({
    required TournamentBracket bracket,
    required bool matchInProgress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = _encode(bracket, matchInProgress: matchInProgress);
    await prefs.setString(_key, jsonEncode(payload));
  }

  static Future<({TournamentBracket bracket, bool matchInProgress})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return _decode(map);
    } catch (_) {
      await clear();
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  static Map<String, dynamic> _encode(
    TournamentBracket bracket, {
    required bool matchInProgress,
  }) {
    final fixtures = <Map<String, dynamic>>[];
    for (final round in TournamentRound.values) {
      for (final fixture in bracket.fixturesFor(round)) {
        fixtures.add(_encodeFixture(fixture));
      }
    }
    return {
      'version': 2,
      'userTeamCode': bracket.userTeam.countryCode,
      'currentRound': bracket.currentRound.name,
      'userEliminated': bracket.userEliminated,
      'championCode': bracket.champion?.countryCode,
      'matchInProgress': matchInProgress,
      'moderateGroupMatchIndices':
          bracket.moderateGroupMatchIndices.toList()..sort(),
      'groups': bracket.groups
          .map(
            (g) => {
              'index': g.index,
              'teamCodes': g.teams.map((t) => t.countryCode).toList(),
            },
          )
          .toList(),
      'fixtures': fixtures,
    };
  }

  static Map<String, dynamic> _encodeFixture(TournamentFixture fixture) {
    return {
      'id': fixture.id,
      'round': fixture.round.name,
      'indexInRound': fixture.indexInRound,
      'groupIndex': fixture.groupIndex,
      'displayOrder': fixture.displayOrder,
      'teamACode': fixture.teamA?.countryCode,
      'teamBCode': fixture.teamB?.countryCode,
      'winnerCode': fixture.winner?.countryCode,
      'scoreA': fixture.scoreA,
      'scoreB': fixture.scoreB,
      'isUserFixture': fixture.isUserFixture,
      'userIsTeamA': fixture.userIsTeamA,
    };
  }

  static ({TournamentBracket bracket, bool matchInProgress}) _decode(
    Map<String, dynamic> map,
  ) {
    final userTeam = teamForCountryCode(map['userTeamCode'] as String);
    if (userTeam == null) {
      throw FormatException('Unknown user team');
    }

    final rounds = <TournamentRound, List<TournamentFixture>>{};
    for (final round in TournamentRound.values) {
      rounds[round] = [];
    }

    for (final raw in map['fixtures'] as List<dynamic>) {
      final fixtureMap = raw as Map<String, dynamic>;
      final round = decodeTournamentRound(fixtureMap['round'] as String);
      rounds[round]!.add(_decodeFixture(fixtureMap));
    }

    for (final round in TournamentRound.values) {
      rounds[round]!.sort((a, b) => a.indexInRound.compareTo(b.indexInRound));
    }

    final groups = _decodeGroups(map, userTeam: userTeam);

    final championCode = map['championCode'] as String?;
    return (
      bracket: TournamentBracket(
        userTeam: userTeam,
        groups: groups,
        rounds: rounds,
        currentRound: decodeTournamentRound(map['currentRound'] as String),
        userEliminated: map['userEliminated'] as bool? ?? false,
        champion:
            championCode == null ? null : teamForCountryCode(championCode),
        moderateGroupMatchIndices: _decodeModerateGroupMatchIndices(map),
      ),
      matchInProgress: map['matchInProgress'] as bool? ?? false,
    );
  }

  static Set<int> _decodeModerateGroupMatchIndices(Map<String, dynamic> map) {
    final raw = map['moderateGroupMatchIndices'] as List<dynamic>?;
    if (raw != null) {
      return raw.map((value) => value as int).toSet();
    }
    final code = map['userTeamCode'] as String? ?? '';
    final picks = List.generate(6, (i) => i)..shuffle(Random(code.hashCode));
    return picks.take(2).toSet();
  }

  static List<TournamentGroup> _decodeGroups(
    Map<String, dynamic> map, {
    required Team userTeam,
  }) {
    final rawGroups = map['groups'] as List<dynamic>?;
    if (rawGroups != null) {
      final groups = rawGroups.map((raw) {
        final groupMap = raw as Map<String, dynamic>;
        final teams = (groupMap['teamCodes'] as List<dynamic>)
            .map((code) => teamForCountryCode(code as String)!)
            .toList();
        return TournamentGroup(
          index: groupMap['index'] as int,
          teams: teams,
        );
      }).toList()
        ..sort((a, b) => a.index.compareTo(b.index));
      return groups;
    }

    // Legacy v1 saves without groups: rebuild from group-stage fixtures.
    final groupFixtures =
        (map['fixtures'] as List<dynamic>? ?? const [])
            .map((raw) => _decodeFixture(raw as Map<String, dynamic>))
            .where((f) => f.round == TournamentRound.groupStage)
            .toList();
    if (groupFixtures.isEmpty) {
      throw FormatException('Missing tournament groups');
    }

    final byGroup = <int, Set<Team>>{};
    for (final fixture in groupFixtures) {
      final index = fixture.groupIndex;
      if (index == null || fixture.teamA == null || fixture.teamB == null) {
        continue;
      }
      byGroup.putIfAbsent(index, () => {}).addAll([
        fixture.teamA!,
        fixture.teamB!,
      ]);
    }

    return byGroup.entries
        .map(
          (entry) => TournamentGroup(
            index: entry.key,
            teams: entry.value.toList(),
          ),
        )
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));
  }

  static TournamentFixture _decodeFixture(Map<String, dynamic> map) {
    Team? team(String? code) =>
        code == null ? null : teamForCountryCode(code);

    return TournamentFixture(
      id: map['id'] as String,
      round: decodeTournamentRound(map['round'] as String),
      indexInRound: map['indexInRound'] as int,
      groupIndex: map['groupIndex'] as int?,
      displayOrder: map['displayOrder'] as int?,
      teamA: team(map['teamACode'] as String?),
      teamB: team(map['teamBCode'] as String?),
      winner: team(map['winnerCode'] as String?),
      scoreA: map['scoreA'] as int?,
      scoreB: map['scoreB'] as int?,
      isUserFixture: map['isUserFixture'] as bool? ?? false,
      userIsTeamA: map['userIsTeamA'] as bool? ?? true,
    );
  }
}

/// Shuffles card order within a round without changing bracket pairings.
void assignShuffledDisplayOrder(
  List<TournamentFixture> fixtures, {
  Random? random,
  int startAt = 0,
}) {
  if (fixtures.isEmpty) return;
  final order = List.generate(fixtures.length, (i) => i)
    ..shuffle(random ?? Random());
  for (var display = 0; display < order.length; display++) {
    fixtures[order[display]].displayOrder = startAt + display;
  }
}

List<TournamentFixture> fixturesSortedForDisplay(
  TournamentRound round,
  TournamentBracket bracket,
) {
  return bracket.fixturesFor(round).toList()
    ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
}
