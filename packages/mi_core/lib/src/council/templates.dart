import 'package:meta/meta.dart';

/// A run configuration, one per scale tier, chosen by the interview.
///
/// **A template sets breadth, not length.** It carries an angle breadth, a
/// number of rounds per barrier and a direction floor, and deliberately
/// carries no stop time, no token ceiling and no step count — because a run
/// that can be stopped by a clock is a run that will be, and the
/// run-until-dry invariant would then hold only on quiet days. The tiers do
/// have expected durations, and [expectation] records them as an expectation
/// in prose. Nothing reads it as a limit; nothing can.
///
/// The floor is the other half of the same idea. It is a *floor on the tier*,
/// not a quota to fill: a run that goes dry below its floor is logged and
/// re-tiered downward, never continued to reach the number, because padding a
/// dossier to a count is the fastest way to destroy the coverage claim the
/// count exists to support.
@immutable
class HarnessTemplate {
  const HarnessTemplate({
    required this.id,
    required this.tier,
    required this.name,
    required this.angleBreadth,
    required this.roundsPerBarrier,
    required this.directionFloor,
    required this.expectation,
  });

  final String id;

  /// Smallest to largest, zero-based. The interview's scale verdict picks one.
  final int tier;

  final String name;

  /// How many exploration angles fan out concurrently in a round. Every angle
  /// is blind to the others, so breadth here is breadth of search, not of
  /// output.
  final int angleBreadth;

  /// How many rounds run before the cartographer re-maps the territory and the
  /// convenor asks whether anything new came back.
  final int roundsPerBarrier;

  /// The number of distinct rated directions this tier is expected to reach.
  /// A floor, never a quota — see the class comment.
  final int directionFloor;

  /// What a run at this tier usually costs in council time. Prose on purpose:
  /// it is an expectation for the client, not an instruction to the run.
  final String expectation;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'tier': tier,
    'name': name,
    'angleBreadth': angleBreadth,
    'roundsPerBarrier': roundsPerBarrier,
    'directionFloor': directionFloor,
  };
}

/// The four tiers. Named for sittings of a court rather than for sizes,
/// because 'small' invites the client to ask for 'large' and the tier is a
/// judgement about the idea, not a purchase.
const List<HarnessTemplate> harnessTemplates = <HarnessTemplate>[
  HarnessTemplate(
    id: 'hearing',
    tier: 0,
    name: 'Hearing',
    angleBreadth: 4,
    roundsPerBarrier: 1,
    directionFloor: 30,
    expectation:
        'About twenty minutes of council time. The run still ends when two '
        'consecutive rounds return nothing new, and not before.',
  ),
  HarnessTemplate(
    id: 'sitting',
    tier: 1,
    name: 'Sitting',
    angleBreadth: 6,
    roundsPerBarrier: 2,
    directionFloor: 50,
    expectation:
        'About an hour of council time, for an idea with more than one '
        'plausible shape.',
  ),
  HarnessTemplate(
    id: 'session',
    tier: 2,
    name: 'Session',
    angleBreadth: 9,
    roundsPerBarrier: 2,
    directionFloor: 75,
    expectation:
        'Two to three hours of council time, for an idea whose medium is '
        'genuinely open.',
  ),
  HarnessTemplate(
    id: 'assize',
    tier: 3,
    name: 'Assize',
    angleBreadth: 12,
    roundsPerBarrier: 3,
    directionFloor: 100,
    expectation:
        'About six hours of council time, for an idea the client intends to '
        'spend a year on.',
  ),
];

HarnessTemplate templateById(String id) => harnessTemplates.firstWhere(
  (HarnessTemplate t) => t.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', 'no such harness template'),
);

HarnessTemplate templateForTier(int tier) => harnessTemplates.firstWhere(
  (HarnessTemplate t) => t.tier == tier,
  orElse: () => throw ArgumentError.value(tier, 'tier', 'no template at tier'),
);
