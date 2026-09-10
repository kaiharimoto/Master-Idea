import 'package:meta/meta.dart';

import '../assembly/integration.dart';
import '../council/templates.dart';
import '../interview/interview_gate.dart';
import 'direction.dart';
import 'ledger.dart';
import 'manifest.dart';
import 'rating.dart';
import 'round.dart';

/// Everything one session is, held as one immutable value.
///
/// The on-disk layout is a directory of files — `interview/`, `rounds/`,
/// `ratings/`, `run_manifest.json` — and this is what those files add up to.
/// The renderers are pure over this value and never reach back into the
/// council, which is what makes a completed session reopenable a month later
/// with no API key and no network.
@immutable
class Session {
  const Session({
    required this.id,
    required this.taskId,
    required this.title,
    required this.createdAt,
    required this.interview,
    required this.manifest,
    this.ledger = const CoverageLedger(),
    this.directions = const <Direction>[],
    this.ratings = const <Rating>[],
    this.challenges = const <Challenge>[],
    this.assumptions = const <Assumption>[],
    this.rounds = const <RoundRecord>[],
    this.selection = const <String>[],
    this.integration,
    this.pitch = '',
  });

  /// The version of the stored shape.
  ///
  /// Written into every stored session so that a build reading files it does
  /// not understand says so, rather than throwing a cast error from four
  /// layers down or — worse — reading a session whose meaning has changed
  /// underneath the same field names.
  static const int schema = 1;

  final String id;

  /// Short kebab-case identifier used for the session directory.
  final String taskId;

  final String title;
  final DateTime createdAt;

  /// Frozen at the gate. Nothing after this point may re-elicit an answer.
  final InterviewRecord interview;

  final RunManifest manifest;
  final CoverageLedger ledger;
  final List<Direction> directions;
  final List<Rating> ratings;
  final List<Challenge> challenges;
  final List<Assumption> assumptions;
  final List<RoundRecord> rounds;

  /// What the client selected in Assembly. The council never decides what
  /// ships, so this list is the only thing the pitch may contain.
  final List<String> selection;

  /// What the selected set becomes together, computed across the whole
  /// selection rather than written into individual directions.
  final Integration? integration;

  /// The generated pitch prompt, verbatim as the session produced it.
  final String pitch;

  HarnessTemplate get template => interview.verdict.template;

  Direction? directionById(String id) {
    for (final Direction d in directions) {
      if (d.id == id) return d;
    }
    return null;
  }

  List<Rating> ratingsFor(String directionId) => ratings
      .where((Rating r) => r.directionId == directionId)
      .toList(growable: false);

  List<Challenge> challengesFor(String directionId) => challenges
      .where((Challenge c) => c.directionId == directionId)
      .toList(growable: false);

  List<Assumption> assumptionsFor(String directionId) => assumptions
      .where((Assumption a) => a.affects.contains(directionId))
      .toList(growable: false);

  List<Direction> get selected => <Direction>[
    for (final String id in selection)
      if (directionById(id) != null) directionById(id)!,
  ];

  /// Cluster id to its members, in the order the council produced them.
  Map<String, List<Direction>> get clusters {
    final Map<String, List<Direction>> out = <String, List<Direction>>{};
    for (final Direction d in directions) {
      out.putIfAbsent(d.clusterId, () => <Direction>[]).add(d);
    }
    return out;
  }

  /// Clusters that do not span conservative, ambitious and reckless.
  ///
  /// A count of directions says nothing about whether the client was offered a
  /// real choice; this does.
  List<String> get clustersNotSpanning {
    final List<String> out = <String>[];
    clusters.forEach((String id, List<Direction> members) {
      final Set<Ambition> have = members
          .map((Direction d) => d.ambition)
          .toSet();
      if (have.length < Ambition.values.length) out.add(id);
    });
    return out..sort();
  }

  /// A copy with what changed.
  ///
  /// [dropIntegration] and [dropPitch] exist because `null` cannot mean
  /// "remove this" in a copy where it already means "leave this alone". Both
  /// are removals the client makes constantly — every change to the selection
  /// invalidates what the set becomes together — and without them the screen
  /// keeps a paragraph describing a selection nobody has any more.
  Session copyWith({
    CoverageLedger? ledger,
    List<Direction>? directions,
    List<Rating>? ratings,
    List<Challenge>? challenges,
    List<Assumption>? assumptions,
    List<RoundRecord>? rounds,
    List<String>? selection,
    Integration? integration,
    String? pitch,
    RunManifest? manifest,
    bool dropIntegration = false,
    bool dropPitch = false,
  }) => Session(
    id: id,
    taskId: taskId,
    title: title,
    createdAt: createdAt,
    interview: interview,
    manifest: manifest ?? this.manifest,
    ledger: ledger ?? this.ledger,
    directions: directions ?? this.directions,
    ratings: ratings ?? this.ratings,
    challenges: challenges ?? this.challenges,
    assumptions: assumptions ?? this.assumptions,
    rounds: rounds ?? this.rounds,
    selection: selection ?? this.selection,
    integration: dropIntegration ? null : (integration ?? this.integration),
    pitch: dropPitch ? '' : (pitch ?? this.pitch),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'id': id,
    'taskId': taskId,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'interview': interview.toJson(),
    'manifest': manifest.toJson(),
    'ledger': ledger.toJson(),
    'directions': directions.map((Direction d) => d.toJson()).toList(),
    'ratings': ratings.map((Rating r) => r.toJson()).toList(),
    'challenges': challenges.map((Challenge c) => c.toJson()).toList(),
    'assumptions': assumptions.map((Assumption a) => a.toJson()).toList(),
    'rounds': rounds.map((RoundRecord r) => r.toJson()).toList(),
    'selection': selection,
    if (integration != null) 'integration': integration!.toJson(),
    if (pitch.isNotEmpty) 'pitch': pitch,
  };

  static Session fromJson(Map<String, Object?> j) => Session(
    id: '${j['id']}',
    taskId: '${j['taskId']}',
    title: '${j['title']}',
    createdAt: DateTime.parse('${j['createdAt']}'),
    interview: InterviewRecord.fromJson(
      j['interview']! as Map<String, Object?>,
    ),
    manifest: RunManifest.fromJson(j['manifest']! as Map<String, Object?>),
    ledger: CoverageLedger.fromJson(
      j['ledger'] as Map<String, Object?>? ?? const <String, Object?>{},
    ),
    directions: (j['directions'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Direction.fromJson(e! as Map<String, Object?>))
        .toList(),
    ratings: (j['ratings'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Rating.fromJson(e! as Map<String, Object?>))
        .toList(),
    challenges: (j['challenges'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Challenge.fromJson(e! as Map<String, Object?>))
        .toList(),
    assumptions: (j['assumptions'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Assumption.fromJson(e! as Map<String, Object?>))
        .toList(),
    rounds: (j['rounds'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => RoundRecord.fromJson(e! as Map<String, Object?>))
        .toList(),
    selection: (j['selection'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
    integration: j['integration'] == null
        ? null
        : Integration.fromJson(j['integration']! as Map<String, Object?>),
    pitch: '${j['pitch'] ?? ''}',
  );
}
