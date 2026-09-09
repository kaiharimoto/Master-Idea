import 'package:meta/meta.dart';

/// What a role is licensed to do inside a round.
///
/// Licences are enumerated rather than described in prose because the
/// independent-rating invariant is enforced against them: a role that holds
/// [CouncilLicence.propose] and [CouncilLicence.rate] at the same time would
/// make it possible — not merely likely — for a direction to be rated by the
/// agent that proposed it. No role in [councilRoles] holds both, and
/// `InvariantSuite` checks that at instance level as well, because the same
/// role played twice is still two different agents.
enum CouncilLicence {
  /// May put a new direction before the council.
  propose,

  /// May attack a direction's mechanism, producing a challenge record.
  challenge,

  /// May give a direction an ordinal verdict on one rating dimension.
  rate,

  /// May record a minority verdict against a rating that has already landed.
  dissent,

  /// May declare a territory of the idea space explored, dropped, or a gap.
  mapTerritory,

  /// May open and close a round, and decide that the run has gone dry.
  convene,

  /// May compute what a selected set of directions becomes together.
  integrate,

  /// May write traceability links and mark revisit points.
  archive,
}

/// One distinct seat on the council.
///
/// Two roles may not share a lens. That is not a style rule: the council's
/// whole claim to coverage rests on the seats looking for different things, so
/// a second role that merely re-words the first inflates the apparent breadth
/// of a round while finding nothing the first would not have found. Every role
/// below therefore records the failure it exists to catch, and
/// `families_test.dart` asserts the lenses are distinct.
@immutable
class CouncilRole {
  const CouncilRole({
    required this.id,
    required this.name,
    required this.lens,
    required this.catches,
    required this.licences,
  });

  /// Stable identifier. Written into every record this role produces, so a
  /// stored session can be audited months later without the catalog in hand.
  final String id;

  /// What the role is called in the dossier.
  final String name;

  /// What this seat is looking for — one sentence, and unique in the catalog.
  final String lens;

  /// The specific failure the council would suffer if this seat were empty.
  final String catches;

  final Set<CouncilLicence> licences;

  bool can(CouncilLicence l) => licences.contains(l);

  /// A role that may both propose and rate would let a direction be judged by
  /// its own advocate. Held here as a property so it is checkable rather than
  /// merely intended.
  bool get isSelfJudging =>
      can(CouncilLicence.propose) && can(CouncilLicence.rate);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'lens': lens,
    'licences': licences.map((CouncilLicence l) => l.name).toList()..sort(),
  };
}

/// The council. At least eight seats is the floor in the brief; ten are here
/// because two of them — the anchorer and the escalator — exist only to make
/// every cluster span conservative through reckless, which no single proposing
/// seat reliably does on its own.
const List<CouncilRole> councilRoles = <CouncilRole>[
  CouncilRole(
    id: 'convenor',
    name: 'Convenor',
    lens: 'Whether this round has anything left to ask.',
    catches:
        'A run that drifts on past dryness, or stops while a named gap is '
        'still unfilled.',
    licences: <CouncilLicence>{CouncilLicence.convene},
  ),
  CouncilRole(
    id: 'cartographer',
    name: 'Cartographer',
    lens: 'Which territories of the idea space have been entered at all.',
    catches:
        'Breadth claimed from a pile of directions that all sit in one corner '
        'of the space.',
    licences: <CouncilLicence>{CouncilLicence.mapTerritory},
  ),
  CouncilRole(
    id: 'prospector',
    name: 'Prospector',
    lens: 'What lies down one assigned angle, blind to the other angles.',
    catches: 'A search that only ever looks where the idea already points.',
    licences: <CouncilLicence>{CouncilLicence.propose},
  ),
  CouncilRole(
    id: 'anchorer',
    name: 'Anchorer',
    lens:
        'The most conservative version of a cluster that is still worth '
        'doing.',
    catches:
        'A dossier of only spectacular options, with nothing the client could '
        'actually start on Monday.',
    licences: <CouncilLicence>{CouncilLicence.propose},
  ),
  CouncilRole(
    id: 'escalator',
    name: 'Escalator',
    lens: 'The reckless version of a cluster, and what it would take.',
    catches:
        'Safe incrementalism: a cluster whose boldest member is still a '
        'feature request.',
    licences: <CouncilLicence>{CouncilLicence.propose},
  ),
  CouncilRole(
    id: 'challenger',
    name: 'Challenger',
    lens: 'Whether a direction can say how it would actually work.',
    catches:
        'Consultant ambition: grand vocabulary with no mechanism behind it.',
    licences: <CouncilLicence>{CouncilLicence.challenge},
  ),
  CouncilRole(
    id: 'assessor',
    name: 'Assessor',
    lens: 'Where a direction falls on one dimension, judged alone.',
    catches: 'Directions entering the dossier unjudged.',
    licences: <CouncilLicence>{CouncilLicence.rate},
  ),
  CouncilRole(
    id: 'dissenter',
    name: 'Dissenter',
    lens: 'The verdict a reasonable seat would give that the assessor did not.',
    catches:
        'Diplomatic ratings: disagreement smoothed into it-depends so that '
        'nothing is ever actually rejected.',
    licences: <CouncilLicence>{CouncilLicence.dissent},
  ),
  CouncilRole(
    id: 'integrator',
    name: 'Integrator',
    lens: 'What a selected set of directions becomes when combined.',
    catches:
        'A pitch that is a list of good ideas rather than one thing to build.',
    licences: <CouncilLicence>{CouncilLicence.integrate},
  ),
  CouncilRole(
    id: 'archivist',
    name: 'Archivist',
    lens: 'Where each direction came from and what the run assumed to get it.',
    catches:
        'An unsourced direction, or an assumption buried in reasoning rather '
        'than marked as a revisit point.',
    licences: <CouncilLicence>{CouncilLicence.archive},
  ),
];

CouncilRole roleById(String id) => councilRoles.firstWhere(
  (CouncilRole r) => r.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', 'no such council role'),
);

/// One agent actually seated in a round.
///
/// The distinction between a role and an instance is what the independent
/// rating invariant is checked against. `assessor` is a role; `assessor#4 in
/// round 2` is the agent that gave a particular verdict, and it is that
/// identity — not the role — that must differ from the direction's proposer.
/// A run that seats the same role twice and lets one instance rate the other's
/// proposal has satisfied the rule as written and broken it as meant.
@immutable
class AgentInstance {
  const AgentInstance({
    required this.roleId,
    required this.round,
    required this.ordinal,
  });

  final String roleId;

  /// Which round this seat was filled in.
  final int round;

  /// Which of the several seats of this role in this round it is.
  final int ordinal;

  CouncilRole get role => roleById(roleId);

  /// The identity written into every record. Stable, sortable, and readable in
  /// a stored file without the catalog.
  String get id => '$roleId#$round.$ordinal';

  @override
  bool operator ==(Object other) => other is AgentInstance && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'roleId': roleId,
    'round': round,
    'ordinal': ordinal,
  };

  static AgentInstance fromJson(Map<String, Object?> j) => AgentInstance(
    roleId: '${j['roleId']}',
    round: (j['round'] as num).toInt(),
    ordinal: (j['ordinal'] as num).toInt(),
  );

  /// Parse the written form, `role#round.ordinal`. Used by the invariant suite
  /// when it is handed nothing but a stored session.
  static AgentInstance parse(String id) {
    final int hash = id.indexOf('#');
    final int dot = id.indexOf('.', hash);
    if (hash < 0 || dot < 0) {
      throw FormatException('not an agent instance id', id);
    }
    return AgentInstance(
      roleId: id.substring(0, hash),
      round: int.parse(id.substring(hash + 1, dot)),
      ordinal: int.parse(id.substring(dot + 1)),
    );
  }
}
