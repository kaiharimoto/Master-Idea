import 'package:meta/meta.dart';

/// What the council did with a territory of the idea space.
enum TerritoryStatus {
  /// Entered, and directions came back from it.
  explored,

  /// Deliberately not entered, with a reason on the record.
  dropped,

  /// Named as missing, and left open until something fills it.
  gap,
}

/// One territory of the idea space, as the cartographer recorded it.
///
/// The ledger is what makes the completeness claim auditable instead of
/// asserted. A council that says 'we covered the space' is worth nothing; a
/// council that shows the space it drew, what it entered, what it refused and
/// why, can be caught out — and being catchable is the entire value.
@immutable
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.firstWrittenInRound,
    this.reason = '',
    this.filledByDirectionIds = const <String>[],
  });

  final String id;
  final String name;

  /// What lies in this territory, in a sentence, so a client can tell whether
  /// their own unspoken idea belongs in it.
  final String description;

  final TerritoryStatus status;

  /// The round this territory was first written in.
  ///
  /// Load-bearing for traceability: a direction may cite a gap only if the gap
  /// was named in an *earlier* round. Without this field a gap invented to
  /// justify a direction already written is indistinguishable from a gap the
  /// direction was generated to fill.
  final int firstWrittenInRound;

  /// Required when [status] is [TerritoryStatus.dropped]. Silent truncation is
  /// the failure this field exists to make impossible.
  final String reason;

  final List<String> filledByDirectionIds;

  bool get isGap => status == TerritoryStatus.gap;
  bool get isDropped => status == TerritoryStatus.dropped;

  Territory fill(String directionId) => Territory(
    id: id,
    name: name,
    description: description,
    status: TerritoryStatus.explored,
    firstWrittenInRound: firstWrittenInRound,
    reason: reason,
    filledByDirectionIds: <String>[...filledByDirectionIds, directionId],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'description': description,
    'status': status.name,
    'firstWrittenInRound': firstWrittenInRound,
    if (reason.isNotEmpty) 'reason': reason,
    'filledByDirectionIds': filledByDirectionIds,
  };

  static Territory fromJson(Map<String, Object?> j) => Territory(
    id: '${j['id']}',
    name: '${j['name']}',
    description: '${j['description']}',
    status: TerritoryStatus.values.firstWhere(
      (TerritoryStatus s) => s.name == j['status'],
      orElse: () => TerritoryStatus.gap,
    ),
    firstWrittenInRound: (j['firstWrittenInRound']! as num).toInt(),
    reason: '${j['reason'] ?? ''}',
    filledByDirectionIds:
        (j['filledByDirectionIds'] as List<Object?>? ?? const <Object?>[])
            .map((Object? e) => '$e')
            .toList(),
  );
}

/// The growing map of the idea space.
@immutable
class CoverageLedger {
  const CoverageLedger({this.territories = const <Territory>[]});

  final List<Territory> territories;

  List<Territory> get explored => territories
      .where((Territory t) => t.status == TerritoryStatus.explored)
      .toList();

  List<Territory> get dropped =>
      territories.where((Territory t) => t.isDropped).toList();

  List<Territory> get gaps =>
      territories.where((Territory t) => t.isGap).toList();

  Territory? byId(String id) {
    for (final Territory t in territories) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// A drop with no reason is a silent truncation wearing a label. Surfaced as
  /// a list so the ledger can be checked in one call rather than by eye.
  List<Territory> get unexplainedDrops =>
      dropped.where((Territory t) => t.reason.trim().isEmpty).toList();

  CoverageLedger add(Territory t) =>
      CoverageLedger(territories: <Territory>[...territories, t]);

  CoverageLedger replace(Territory t) => CoverageLedger(
    territories: <Territory>[
      for (final Territory existing in territories)
        if (existing.id == t.id) t else existing,
    ],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'territories': territories.map((Territory t) => t.toJson()).toList(),
  };

  static CoverageLedger fromJson(Map<String, Object?> j) => CoverageLedger(
    territories: (j['territories'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Territory.fromJson(e! as Map<String, Object?>))
        .toList(),
  );
}
