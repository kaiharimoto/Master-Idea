import 'package:meta/meta.dart';

/// Where a direction sits between the safe version and the wild one.
///
/// Every cluster must span all three. A cluster of three ambitious variants is
/// a cluster with one member wearing three hats, and it is the commonest way a
/// direction count is reached without the idea space being covered.
enum Ambition { conservative, ambitious, reckless }

/// What a direction came from.
///
/// Traceability is a hard invariant, so this is not metadata — a direction
/// without a resolvable link does not enter the dossier at all. Two sources
/// are legitimate: something the client said, or a gap the cartographer named
/// in an *earlier* round. A gap written in the same round as the direction it
/// justifies is a rationalisation written after the fact, which is why the
/// round is recorded and checked.
@immutable
class TraceLink {
  const TraceLink({this.answerModuleId, this.gapId, required this.quote});

  /// The interview answer this came out of, by module id.
  final String? answerModuleId;

  /// The named ledger gap this was generated to fill.
  final String? gapId;

  /// The specific phrase in the answer, or the gap's own wording, that the
  /// direction answers. A link to a four-hundred-word answer proves nothing;
  /// a link to the clause inside it can be checked in seconds.
  final String quote;

  bool get isSourced => answerModuleId != null || gapId != null;

  Map<String, Object?> toJson() => <String, Object?>{
    if (answerModuleId != null) 'answerModuleId': answerModuleId,
    if (gapId != null) 'gapId': gapId,
    'quote': quote,
  };

  static TraceLink fromJson(Map<String, Object?> j) => TraceLink(
    answerModuleId: j['answerModuleId'] as String?,
    gapId: j['gapId'] as String?,
    quote: '${j['quote']}',
  );
}

/// One direction the council put before the client.
@immutable
class Direction {
  const Direction({
    required this.id,
    required this.clusterId,
    required this.clusterName,
    required this.ambition,
    required this.title,
    required this.statement,
    required this.mechanism,
    required this.proposedBy,
    required this.round,
    required this.angleId,
    required this.trace,
  });

  final String id;

  /// Directions grouped by the question about the idea they answer. The
  /// cluster, not the direction, is what must span conservative to reckless.
  final String clusterId;
  final String clusterName;

  final Ambition ambition;

  final String title;

  /// The direction itself, stated as a decision the client could take.
  final String statement;

  /// How it would actually work. Empty here is not a stylistic lapse — it is
  /// the consultant-ambition anti-pattern, and the mechanism dimension will
  /// rate it `absent`.
  final String mechanism;

  /// The agent instance that proposed it, in `role#round.ordinal` form. No
  /// rating of this direction may carry this identity.
  final String proposedBy;

  final int round;
  final String angleId;
  final TraceLink trace;

  /// A short signature used for deduplication. Deliberately built from the
  /// substance — what it is and how it works — and not from the title, because
  /// two proposers describing the same move rarely choose the same title and
  /// always describe the same mechanism.
  String get substance => '$statement $mechanism';

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'clusterId': clusterId,
    'clusterName': clusterName,
    'ambition': ambition.name,
    'title': title,
    'statement': statement,
    'mechanism': mechanism,
    'proposedBy': proposedBy,
    'round': round,
    'angleId': angleId,
    'trace': trace.toJson(),
  };

  static Direction fromJson(Map<String, Object?> j) => Direction(
    id: '${j['id']}',
    clusterId: '${j['clusterId']}',
    clusterName: '${j['clusterName']}',
    ambition: Ambition.values.firstWhere(
      (Ambition a) => a.name == j['ambition'],
      orElse: () => Ambition.ambitious,
    ),
    title: '${j['title']}',
    statement: '${j['statement']}',
    mechanism: '${j['mechanism']}',
    proposedBy: '${j['proposedBy']}',
    round: (j['round']! as num).toInt(),
    angleId: '${j['angleId']}',
    trace: TraceLink.fromJson(j['trace']! as Map<String, Object?>),
  );
}

/// A challenger's attack on a direction's mechanism.
///
/// Kept as its own record rather than folded into the direction, because a
/// challenge that survives is evidence and a challenge that is answered is
/// history. Both are worth reading; neither is worth losing.
@immutable
class Challenge {
  const Challenge({
    required this.directionId,
    required this.by,
    required this.attack,
    required this.answered,
    this.answer = '',
  });

  final String directionId;

  /// The challenger's agent instance id.
  final String by;

  final String attack;
  final bool answered;
  final String answer;

  Map<String, Object?> toJson() => <String, Object?>{
    'directionId': directionId,
    'by': by,
    'attack': attack,
    'answered': answered,
    if (answer.isNotEmpty) 'answer': answer,
  };

  static Challenge fromJson(Map<String, Object?> j) => Challenge(
    directionId: '${j['directionId']}',
    by: '${j['by']}',
    attack: '${j['attack']}',
    answered: j['answered'] == true,
    answer: '${j['answer'] ?? ''}',
  );
}

/// An assumption the run made in the client's absence.
///
/// Every one of these appears in the dossier as a marked revisit point,
/// whether or not it answers a declared unknown. The ones that do cite the
/// unknown they exercise; the ones that do not are the interesting ones,
/// because they are where the run went beyond its licence and said so.
@immutable
class Assumption {
  const Assumption({
    required this.id,
    required this.round,
    required this.made,
    required this.because,
    required this.affects,
    this.answersUnknownId,
  });

  final String id;
  final int round;

  /// What was assumed, in one sentence the client can overturn.
  final String made;

  final String because;

  /// Direction ids this assumption is load-bearing for.
  final List<String> affects;

  /// The declared unknown this exercises, if any.
  final String? answersUnknownId;

  bool get isLicensed => answersUnknownId != null;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'round': round,
    'made': made,
    'because': because,
    'affects': affects,
    if (answersUnknownId != null) 'answersUnknownId': answersUnknownId,
  };

  static Assumption fromJson(Map<String, Object?> j) => Assumption(
    id: '${j['id']}',
    round: (j['round']! as num).toInt(),
    made: '${j['made']}',
    because: '${j['because']}',
    affects: (j['affects'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
    answersUnknownId: j['answersUnknownId'] as String?,
  );
}
