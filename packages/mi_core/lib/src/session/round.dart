import 'package:meta/meta.dart';

/// What one angle returned in one round.
///
/// Angles fan out concurrently and blind to each other, so a return is the
/// only record that an angle was actually searched. An angle configured and
/// never returning anything — in any stored session — is a family member that
/// never executed, which the brief treats as a failure rather than as an
/// unused option.
@immutable
class AngleReturn {
  const AngleReturn({
    required this.angleId,
    required this.by,
    required this.proposedIds,
    required this.keptIds,
    this.exhausted = false,
    this.unread = const <String>[],
  });

  final String angleId;

  /// The prospector instance seated on this angle.
  final String by;

  /// Everything it proposed, before deduplication.
  final List<String> proposedIds;

  /// What survived deduplication. The difference between the two lists is the
  /// round's real yield.
  final List<String> keptIds;

  /// The seat said `mi-none`: this angle has nothing left.
  ///
  /// Recorded because it is the difference between an angle that is finished
  /// and a reply nobody could read, and dryness means the first of those. A
  /// round of silence that was really a round of misreads is a run ended by
  /// a parser.
  final bool exhausted;

  /// Lines inside a block the parser could not use.
  ///
  /// Kept for the same reason: a misread that disappears silently is
  /// indistinguishable from a council that had nothing to say.
  final List<String> unread;

  /// The seat answered, and nothing came of it that it did not claim.
  bool get returnedNothingReadable =>
      !exhausted && proposedIds.isEmpty && unread.isNotEmpty;

  Map<String, Object?> toJson() => <String, Object?>{
    'angleId': angleId,
    'by': by,
    'proposedIds': proposedIds,
    'keptIds': keptIds,
    'exhausted': exhausted,
    if (unread.isNotEmpty) 'unread': unread,
  };

  static AngleReturn fromJson(Map<String, Object?> j) => AngleReturn(
    angleId: '${j['angleId']}',
    by: '${j['by']}',
    proposedIds: (j['proposedIds'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
    keptIds: (j['keptIds'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
    exhausted: j['exhausted'] == true,
    unread: (j['unread'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
  );
}

/// A candidate the deduplicator refused, and why.
///
/// Kept because the run-until-dry invariant is a claim about what a round
/// *returned*, and a round that returned twelve restatements of yesterday's
/// work returned nothing. Without these records, dryness is a claim; with
/// them, it is a computation someone else can repeat.
@immutable
class DedupRejection {
  const DedupRejection({
    required this.candidateTitle,
    required this.candidateSubstance,
    required this.againstDirectionId,
    required this.ruleId,
    required this.similarity,
  });

  final String candidateTitle;
  final String candidateSubstance;

  /// The direction already on the record that this duplicated.
  final String againstDirectionId;

  /// Which deduplication rule made the call, by id. Named so a session judged
  /// under one rule is not silently compared against another.
  final String ruleId;

  /// The rule's own measure. Not a rating and never rendered as one — the
  /// prohibition on numerals covers verdicts, which this is not.
  final double similarity;

  Map<String, Object?> toJson() => <String, Object?>{
    'candidateTitle': candidateTitle,
    'candidateSubstance': candidateSubstance,
    'againstDirectionId': againstDirectionId,
    'ruleId': ruleId,
    'similarity': similarity,
  };

  static DedupRejection fromJson(Map<String, Object?> j) => DedupRejection(
    candidateTitle: '${j['candidateTitle']}',
    candidateSubstance: '${j['candidateSubstance']}',
    againstDirectionId: '${j['againstDirectionId']}',
    ruleId: '${j['ruleId']}',
    similarity: (j['similarity']! as num).toDouble(),
  );
}

/// A proposal the run refused for a reason other than duplication.
///
/// Refusals are recorded rather than dropped because they are the evidence
/// that the invariants were enforced during the run instead of asserted after
/// it. A direction refused for citing a gap that was invented in its own round
/// is the traceability invariant visibly doing its job.
@immutable
class Refusal {
  const Refusal({
    required this.candidateTitle,
    required this.reason,
    required this.kind,
  });

  final String candidateTitle;

  /// `unsourced`, `gap-not-yet-written`, `no-mechanism`.
  final String kind;

  final String reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'candidateTitle': candidateTitle,
    'kind': kind,
    'reason': reason,
  };

  static Refusal fromJson(Map<String, Object?> j) => Refusal(
    candidateTitle: '${j['candidateTitle']}',
    kind: '${j['kind']}',
    reason: '${j['reason']}',
  );
}

/// One round, which is a barrier.
///
/// Rounds are barriers because the run-until-dry invariant is a statement
/// about consecutive rounds, and 'consecutive' has no meaning in a free-for-all
/// where work from three generations overlaps. Inside a round the angles fan
/// out concurrently and each direction pipelines through challenge and rating
/// as soon as it exists; the barrier is only at the end, where the question
/// 'did anything new come back' is asked.
@immutable
class RoundRecord {
  const RoundRecord({
    required this.number,
    required this.angleSet,
    required this.returns,
    required this.rejections,
    required this.refusals,
    required this.newDirectionIds,
    required this.gapsNamed,
    required this.startedAt,
    required this.endedAt,
  });

  final int number;

  /// The angles used, in the order they were seated. Breadth is
  /// `angleSet.length`, and a dryness decision may not be made on a round
  /// whose breadth is narrower than the round before it.
  final List<String> angleSet;

  final List<AngleReturn> returns;
  final List<DedupRejection> rejections;

  /// Proposals refused on an invariant, not on duplication.
  final List<Refusal> refusals;

  final List<String> newDirectionIds;

  /// Territories the cartographer named as gaps at this barrier.
  final List<String> gapsNamed;

  final DateTime startedAt;
  final DateTime endedAt;

  /// The only definition of 'new' this system has.
  bool get returnedSomethingNew => newDirectionIds.isNotEmpty;

  int get breadth => angleSet.length;

  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    'angleSet': angleSet,
    'returns': returns.map((AngleReturn r) => r.toJson()).toList(),
    'rejections': rejections.map((DedupRejection r) => r.toJson()).toList(),
    'refusals': refusals.map((Refusal r) => r.toJson()).toList(),
    'newDirectionIds': newDirectionIds,
    'gapsNamed': gapsNamed,
    'returnedSomethingNew': returnedSomethingNew,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
  };

  static RoundRecord fromJson(Map<String, Object?> j) => RoundRecord(
    number: (j['number']! as num).toInt(),
    angleSet: (j['angleSet']! as List<Object?>)
        .map((Object? e) => '$e')
        .toList(),
    returns: (j['returns'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => AngleReturn.fromJson(e! as Map<String, Object?>))
        .toList(),
    rejections: (j['rejections'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => DedupRejection.fromJson(e! as Map<String, Object?>))
        .toList(),
    refusals: (j['refusals'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Refusal.fromJson(e! as Map<String, Object?>))
        .toList(),
    newDirectionIds:
        (j['newDirectionIds'] as List<Object?>? ?? const <Object?>[])
            .map((Object? e) => '$e')
            .toList(),
    gapsNamed: (j['gapsNamed'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => '$e')
        .toList(),
    startedAt: DateTime.parse('${j['startedAt']}'),
    endedAt: DateTime.parse('${j['endedAt']}'),
  );
}

/// Why the run stopped.
///
/// A run may end for exactly one reason: two consecutive rounds returned
/// nothing new. Not a clock, not a token ceiling, not a step count — so this
/// record names both deciding rounds and both their angle sets, and the
/// invariant suite refuses a decision whose second round was narrower than its
/// first. A run declared dry on a narrowed round is a timer with better
/// manners.
@immutable
class DrynessDecision {
  const DrynessDecision({
    required this.firstRound,
    required this.secondRound,
    required this.firstAngleSet,
    required this.secondAngleSet,
    required this.dedupRuleId,
    required this.decidedAt,
    required this.directionCount,
    required this.floorAtTier,
  });

  final int firstRound;
  final int secondRound;
  final List<String> firstAngleSet;
  final List<String> secondAngleSet;
  final String dedupRuleId;
  final DateTime decidedAt;

  /// What the session actually held when it went dry, and the floor its tier
  /// expected. A run that goes dry below its floor is logged and re-tiered
  /// downward — never continued to reach the number.
  final int directionCount;
  final int floorAtTier;

  bool get wentDryBelowFloor => directionCount < floorAtTier;

  Map<String, Object?> toJson() => <String, Object?>{
    'firstRound': firstRound,
    'secondRound': secondRound,
    'firstAngleSet': firstAngleSet,
    'secondAngleSet': secondAngleSet,
    'dedupRuleId': dedupRuleId,
    'decidedAt': decidedAt.toIso8601String(),
    'directionCount': directionCount,
    'floorAtTier': floorAtTier,
    'wentDryBelowFloor': wentDryBelowFloor,
  };

  static DrynessDecision fromJson(Map<String, Object?> j) => DrynessDecision(
    firstRound: (j['firstRound']! as num).toInt(),
    secondRound: (j['secondRound']! as num).toInt(),
    firstAngleSet: (j['firstAngleSet']! as List<Object?>)
        .map((Object? e) => '$e')
        .toList(),
    secondAngleSet: (j['secondAngleSet']! as List<Object?>)
        .map((Object? e) => '$e')
        .toList(),
    dedupRuleId: '${j['dedupRuleId']}',
    decidedAt: DateTime.parse('${j['decidedAt']}'),
    directionCount: (j['directionCount']! as num).toInt(),
    floorAtTier: (j['floorAtTier']! as num).toInt(),
  );
}
