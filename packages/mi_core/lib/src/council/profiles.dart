import 'package:meta/meta.dart';

/// An adaptation for the medium the idea lives in.
///
/// A profile earns its place only if it changes **what a good direction is**.
/// A profile that changes vocabulary — saying 'chapter' where another says
/// 'screen' — is cosmetic, and cosmetic profiles are how a tool that claims to
/// serve any creative project turns out to be a software tool wearing costumes.
/// Each profile below therefore carries a standard a direction is held to in
/// that medium, and a disqualifier that would sink a direction here and
/// nowhere else.
@immutable
class DomainProfile {
  const DomainProfile({
    required this.id,
    required this.name,
    required this.essentialModules,
    required this.goodDirection,
    required this.disqualifier,
    required this.favouredAngles,
  });

  final String id;
  final String name;

  /// Interview modules this medium makes non-optional. The interview composes
  /// from the module bank, and these are the ones it may not skip.
  final List<String> essentialModules;

  /// What a good direction looks like in this medium.
  final String goodDirection;

  /// What sinks a direction here and would be unremarkable elsewhere.
  final String disqualifier;

  /// Angles that tend to be productive here. Ordering only — every angle
  /// remains reachable, because a profile that could switch an angle off would
  /// let a medium quietly narrow the search.
  final List<String> favouredAngles;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};
}

/// The profile catalog. The floor is six; seven are here.
const List<DomainProfile> domainProfiles = <DomainProfile>[
  DomainProfile(
    id: 'essay',
    name: 'Essay or argument',
    essentialModules: <String>[
      'claim',
      'existing-alternatives',
      'audience',
      'success-test',
    ],
    goodDirection:
        'A different claim, or the same claim reached by an argument that '
        'costs the reader something. Structure, evidence and the concession '
        'it is willing to make are the substance.',
    disqualifier:
        'A direction that is a topic rather than a claim. An essay direction '
        'that cannot be contradicted is not a direction.',
    favouredAngles: <String>[
      'inversion',
      'antagonist',
      'first-principles',
      'audience-shift',
    ],
  ),
  DomainProfile(
    id: 'story',
    name: 'Story or script',
    essentialModules: <String>[
      'premise',
      'stakes',
      'audience',
      'taboos',
      'success-test',
    ],
    goodDirection:
        'A different engine of change — who wants what, what stands in the '
        'way, and what the ending costs. Directions are judged on the '
        'pressure they generate, not on setting.',
    disqualifier:
        'A world without a conflict engine. Elaborate setting with no source '
        'of pressure is a mood, and moods do not sustain a draft.',
    favouredAngles: <String>[
      'inversion',
      'audience-shift',
      'time-shift',
      'failure-autopsy',
    ],
  ),
  DomainProfile(
    id: 'song',
    name: 'Song or composition',
    essentialModules: <String>['premise', 'ceiling', 'constraints', 'taboos'],
    goodDirection:
        'A different relationship between form and feeling — a structure, a '
        'restriction, or an arrangement decision that produces an effect the '
        'listener cannot get elsewhere.',
    disqualifier:
        'A direction that names a genre and stops. Genre is a shelf, not a '
        'decision.',
    favouredAngles: <String>[
      'constraint-tightening',
      'analogy-transfer',
      'medium-shift',
      'scale-jump',
    ],
  ),
  DomainProfile(
    id: 'software',
    name: 'Software',
    essentialModules: <String>[
      'mechanism',
      'existing-alternatives',
      'constraints',
      'unknowns',
      'success-test',
    ],
    goodDirection:
        'A different thing to build, not a different feature list. The '
        'direction changes what the software is for or what it refuses to do.',
    disqualifier:
        'A feature request on the idea as stated. In this medium the pull '
        'towards safe incrementalism is strongest, and it is judged hardest.',
    favouredAngles: <String>[
      'first-principles',
      'constraint-removal',
      'antagonist',
      'adjacent-possible',
    ],
  ),
  DomainProfile(
    id: 'product',
    name: 'Product or venture',
    essentialModules: <String>[
      'audience',
      'existing-alternatives',
      'stakes',
      'constraints',
      'unknowns',
    ],
    goodDirection:
        'A different bet about who pays, what they are buying instead today, '
        'and what has to be true for the exchange to hold.',
    disqualifier:
        'A direction with no named buyer. An audience of everyone is an '
        'audience of nobody, and here that is fatal rather than vague.',
    favouredAngles: <String>[
      'antagonist',
      'audience-shift',
      'adjacent-possible',
      'failure-autopsy',
    ],
  ),
  DomainProfile(
    id: 'research',
    name: 'Research or investigation',
    essentialModules: <String>[
      'claim',
      'mechanism',
      'unknowns',
      'constraints',
      'success-test',
    ],
    goodDirection:
        'A different question, or the same question made answerable — a '
        'method, a dataset, or a comparison that would settle something.',
    disqualifier:
        'A question that no possible result would change. Unfalsifiable here '
        'is disqualifying, where in an essay it is merely weak.',
    favouredAngles: <String>[
      'first-principles',
      'inversion',
      'analogy-transfer',
      'constraint-removal',
    ],
  ),
  DomainProfile(
    id: 'game',
    name: 'Game or interactive work',
    essentialModules: <String>[
      'mechanism',
      'stakes',
      'audience',
      'constraints',
      'taboos',
    ],
    goodDirection:
        'A different loop — what the player does repeatedly, what it costs '
        'them, and what the system does back. Fiction serves the loop.',
    disqualifier:
        'A setting or a story with no verb. Here the mechanism is the work, '
        'so a direction with no action is empty however vivid it is.',
    favouredAngles: <String>[
      'constraint-tightening',
      'analogy-transfer',
      'scale-jump',
      'inversion',
    ],
  ),
];

DomainProfile profileById(String id) => domainProfiles.firstWhere(
  (DomainProfile p) => p.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', 'no such domain profile'),
);

/// The same, or null.
///
/// For the places that only need to *print* a name: a session written by
/// another build, or read out of files a person edited, can name something
/// this catalog does not have — and a lookup that throws while a list is
/// being built takes the whole screen down, including every other session on
/// it. A run may still demand the strict one.
DomainProfile? profileByIdOrNull(String id) {
  for (final DomainProfile p in domainProfiles) {
    if (p.id == id) return p;
  }
  return null;
}
