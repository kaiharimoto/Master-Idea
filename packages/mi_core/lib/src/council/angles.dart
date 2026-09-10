import 'package:meta/meta.dart';

/// One independent way of searching the idea space.
///
/// Angles vary by **search modality, not by topic**. That is the whole point:
/// an angle earns its seat only if it can find something the other angles
/// structurally cannot. Ten angles that are ten subject areas fan out into the
/// same neighbourhood ten times and report breadth; ten angles that are ten
/// ways of looking return things that surprise each other.
///
/// Angles run blind to one another within a round. Nothing here carries state
/// between them — the blindness is enforced by [ExplorationAngle] being all
/// the context a prospector is given about where to look.
@immutable
class ExplorationAngle {
  const ExplorationAngle({
    required this.id,
    required this.name,
    required this.modality,
    required this.instruction,
    required this.findsWhatOthersCannot,
  });

  final String id;
  final String name;

  /// The search operation, in a few words. Unique across the catalog.
  final String modality;

  /// What the prospector seated on this angle is told to do. This is the
  /// entire brief it gets about direction-finding, so it has to be sufficient
  /// on its own.
  final String instruction;

  /// The claim that justifies the seat: what this angle reaches that no other
  /// angle in the catalog can. Asserted as distinct in `families_test.dart`.
  final String findsWhatOthersCannot;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'modality': modality,
  };
}

/// The angle catalog. The floor is ten; twelve are here.
const List<ExplorationAngle> explorationAngles = <ExplorationAngle>[
  ExplorationAngle(
    id: 'inversion',
    name: 'Inversion',
    modality: 'Negate the central premise and see what survives.',
    instruction:
        'Take the single claim the idea rests on and assume the opposite is '
        'true. Propose directions that are only reachable from that inverted '
        'premise. Do not propose the idea back with a caveat.',
    findsWhatOthersCannot:
        'Directions that contradict the stated idea and are better than it.',
  ),
  ExplorationAngle(
    id: 'constraint-removal',
    name: 'Constraint removal',
    modality: 'Delete a hard constraint and follow what becomes possible.',
    instruction:
        'Name a constraint the idea currently treats as fixed — budget, '
        'medium, audience, physics, the law, the calendar — delete exactly '
        'one of them, and propose what the idea becomes with it gone.',
    findsWhatOthersCannot:
        'The version of the idea that is being suppressed by a constraint '
        'nobody has questioned.',
  ),
  ExplorationAngle(
    id: 'constraint-tightening',
    name: 'Constraint tightening',
    modality: 'Impose a brutal constraint and find what it forces.',
    instruction:
        'Impose a constraint far harsher than anything the idea currently '
        'faces — a tenth of the time, one page, one performer, no budget, one '
        'sitting — and propose the directions that constraint forces into '
        'existence.',
    findsWhatOthersCannot:
        'The compressed version whose severity is the point, which no relaxed '
        'search reaches.',
  ),
  ExplorationAngle(
    id: 'analogy-transfer',
    name: 'Analogy transfer',
    modality: 'Import a working mechanism from a distant field.',
    instruction:
        'Find a field with no connection to this idea that has already solved '
        'a structurally identical problem. Carry its mechanism across intact '
        'and propose what it makes possible here. Name the source field.',
    findsWhatOthersCannot:
        'Mechanisms that exist and work, but not yet in this domain.',
  ),
  ExplorationAngle(
    id: 'audience-shift',
    name: 'Audience shift',
    modality: 'Change who it is for and let the idea re-form around them.',
    instruction:
        'Move the idea to a different audience — an expert, a child, an '
        'adversary, a stranger a century from now, someone who would never '
        'choose it — and propose the directions that audience makes obvious.',
    findsWhatOthersCannot:
        'Directions whose value is entirely a function of who receives them.',
  ),
  ExplorationAngle(
    id: 'medium-shift',
    name: 'Medium shift',
    modality: 'Change the form the idea takes.',
    instruction:
        'Move the idea into a different medium — prose, film, software, a '
        'live performance, an object, an institution — and propose what only '
        'that medium can do with it. Then say what is lost.',
    findsWhatOthersCannot:
        'Directions that require a change of form and so are invisible to any '
        'search that assumes the medium.',
  ),
  ExplorationAngle(
    id: 'time-shift',
    name: 'Time shift',
    modality: 'Move the idea along the timeline, forwards or back.',
    instruction:
        'Place the idea in another era or on another timescale — an afternoon, '
        'a decade, a century, before the technology it assumes existed, after '
        'it is obsolete — and propose the directions that placement produces.',
    findsWhatOthersCannot:
        'Directions that depend on duration or period, which a present-tense '
        'search never poses.',
  ),
  ExplorationAngle(
    id: 'scale-jump',
    name: 'Scale jump',
    modality: 'Change the order of magnitude in one direction.',
    instruction:
        'Multiply or divide the idea by a hundred — of audience, of length, of '
        'cost, of ambition — and propose what is only true at that size. A '
        'direction that survives the jump unchanged is not a finding.',
    findsWhatOthersCannot:
        'Directions that only exist at a size nobody proposed.',
  ),
  ExplorationAngle(
    id: 'failure-autopsy',
    name: 'Failure autopsy',
    modality: 'Start from how it fails and work backwards.',
    instruction:
        'Assume the idea has already been attempted and failed badly. Write '
        'the most convincing cause of death, then propose the directions that '
        'cause makes necessary.',
    findsWhatOthersCannot:
        'Directions that exist to survive a specific failure, which no '
        'optimistic search generates.',
  ),
  ExplorationAngle(
    id: 'adjacent-possible',
    name: 'Adjacent possible',
    modality: 'Step one move from what already exists.',
    instruction:
        'Survey what already exists in this space and propose the nearest '
        'unoccupied position to it — the move a competent practitioner could '
        'make tomorrow and nobody has. Name what already exists.',
    findsWhatOthersCannot:
        'The near miss that everything else in the catalog jumps clean over.',
  ),
  ExplorationAngle(
    id: 'first-principles',
    name: 'First principles',
    modality: 'Rebuild from the underlying need, ignoring the idea as stated.',
    instruction:
        'Set the idea aside entirely. Name the need it is serving, then build '
        'the shortest path to that need from nothing. Propose what you get, '
        'even where it makes the original idea unnecessary.',
    findsWhatOthersCannot:
        'The direction that reveals the stated idea to be an accident of how '
        'it was first described.',
  ),
  ExplorationAngle(
    id: 'antagonist',
    name: 'Antagonist',
    modality: 'Build what would beat it.',
    instruction:
        'You are a rival with the same resources and no attachment to this '
        'idea. Propose what you would build to make it irrelevant, then '
        'propose the directions that answer.',
    findsWhatOthersCannot:
        'Directions defined by competitive pressure rather than by internal '
        'logic.',
  ),
];

ExplorationAngle angleById(String id) => explorationAngles.firstWhere(
  (ExplorationAngle a) => a.id == id,
  orElse: () =>
      throw ArgumentError.value(id, 'id', 'no such exploration angle'),
);

/// The same, or null.
///
/// For the places that only need to *print* a name: a session written by
/// another build, or read out of files a person edited, can name something
/// this catalog does not have — and a lookup that throws while a list is
/// being built takes the whole screen down, including every other session on
/// it. A run may still demand the strict one.
ExplorationAngle? angleByIdOrNull(String id) {
  for (final ExplorationAngle a in explorationAngles) {
    if (a.id == id) return a;
  }
  return null;
}
