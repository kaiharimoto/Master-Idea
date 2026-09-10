import 'package:meta/meta.dart';

import '../council/profiles.dart';

/// Which part of the confirmed brief a module is responsible for producing.
///
/// Modules are grouped by product rather than by subject so that a composed
/// interview can be checked for completeness before it is put to the client:
/// an interview that never asks anything producing [BriefPart.unknowns] has
/// no licence list at the end, and a six-hour run then has nothing it is
/// allowed to decide on its own.
enum BriefPart { function, ambition, reason, scale, unknowns }

/// One reusable unit the interview is composed from.
///
/// The interview is composed from a bank rather than improvised because the
/// interview is the only moment a human is present. An improvised interview
/// is as good as the model's mood that day; a composed one is as good as the
/// bank, and the bank can be improved between sessions.
@immutable
class InterviewModule {
  const InterviewModule({
    required this.id,
    required this.name,
    required this.produces,
    required this.question,
    required this.whyItMatters,
    this.always = false,
  });

  final String id;
  final String name;
  final BriefPart produces;

  /// What is actually put to the client. One question, not a form.
  final String question;

  /// What downstream part of the run breaks if this goes unanswered. Shown to
  /// the client when they ask why they are being asked.
  final String whyItMatters;

  /// Included in every composed interview regardless of medium.
  final bool always;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'produces': produces.name,
  };
}

/// The module bank. The floor is twelve; fifteen are here.
const List<InterviewModule> interviewModules = <InterviewModule>[
  InterviewModule(
    id: 'raw-idea',
    name: 'The idea itself',
    produces: BriefPart.function,
    always: true,
    question:
        'Say the idea in your own words, however unfinished. Do not tidy it '
        'up — the untidy version carries information the tidy one loses.',
    whyItMatters:
        'Everything downstream is traced back to an answer here. Without it '
        'no direction in the dossier can be sourced.',
  ),
  InterviewModule(
    id: 'medium',
    name: 'Medium',
    produces: BriefPart.scale,
    always: true,
    question:
        'What form does this take when it exists — an essay, a story, a song, '
        'software, a product, a study, a game, or something else?',
    whyItMatters:
        'Selects the domain profile, which changes what counts as a good '
        'direction rather than merely how it is worded.',
  ),
  InterviewModule(
    id: 'premise',
    name: 'Premise',
    produces: BriefPart.function,
    question:
        'What happens in it? Describe the thing itself as someone '
        'encountering it would meet it, not as a summary of its purpose.',
    whyItMatters:
        'Expressive media are judged on what the work does to whoever meets '
        'it. A purpose statement cannot be rated on that.',
  ),
  InterviewModule(
    id: 'claim',
    name: 'Claim',
    produces: BriefPart.function,
    question:
        'What does it assert that a reasonable person could disagree with?',
    whyItMatters:
        'A claim nobody could contradict gives the council nothing to argue, '
        'and an unarguable direction cannot be rated.',
  ),
  InterviewModule(
    id: 'mechanism',
    name: 'Mechanism',
    produces: BriefPart.function,
    question:
        'How would it actually work? Name the part you are least sure of.',
    whyItMatters:
        'The mechanism dimension is the council\'s only defence against grand '
        'vocabulary with nothing underneath it, and it needs a baseline.',
  ),
  InterviewModule(
    id: 'audience',
    name: 'Audience',
    produces: BriefPart.reason,
    always: true,
    question:
        'Who is this for, specifically enough that you could name one of them?',
    whyItMatters:
        'The audience-shift angle needs a position to shift from, and several '
        'profiles disqualify a direction with no named recipient.',
  ),
  InterviewModule(
    id: 'existing-alternatives',
    name: 'What already exists',
    produces: BriefPart.reason,
    always: true,
    question:
        'What does someone use or read or listen to instead of this today, '
        'and why does this deserve to exist alongside it?',
    whyItMatters:
        'The adjacent-possible and antagonist angles both search from what '
        'already exists. Without this they search from nothing.',
  ),
  InterviewModule(
    id: 'ceiling',
    name: 'Ceiling',
    produces: BriefPart.ambition,
    always: true,
    question:
        'If this went as far as it possibly could, what would it be? Answer '
        'without hedging — the hedge is the next question.',
    whyItMatters:
        'The pitch is built for the highest ceiling the idea can carry. An '
        'unstated ceiling becomes whatever the model finds comfortable.',
  ),
  InterviewModule(
    id: 'floor',
    name: 'Floor',
    produces: BriefPart.ambition,
    question:
        'What is the smallest version of this you would still be glad you '
        'made?',
    whyItMatters:
        'Gives the anchorer a real conservative position, so the conservative '
        'end of every cluster is a decision rather than a shrug.',
  ),
  InterviewModule(
    id: 'stakes',
    name: 'Stakes',
    produces: BriefPart.ambition,
    question: 'If it works, what changes — for you, or for anyone else?',
    whyItMatters:
        'The consequence dimension asks what a direction would actually '
        'change. It is meaningless without a stated stake to change.',
  ),
  InterviewModule(
    id: 'appetite',
    name: 'Appetite',
    produces: BriefPart.scale,
    always: true,
    question:
        'How much of your life is this idea worth — an afternoon, a month, a '
        'year? Answer about the idea, not about your calendar.',
    whyItMatters:
        'The scale verdict picks the harness template from this. Judging it '
        'from enthusiasm instead produces a six-hour run on a postcard.',
  ),
  InterviewModule(
    id: 'constraints',
    name: 'Constraints',
    produces: BriefPart.scale,
    question:
        'What is genuinely fixed — skill, budget, time, format, obligation? '
        'Only the ones that are actually immovable.',
    whyItMatters:
        'Constraint removal and constraint tightening both need a true list. '
        'A constraint invented for comfort produces fake reckless options.',
  ),
  InterviewModule(
    id: 'taboos',
    name: 'Out of bounds',
    produces: BriefPart.unknowns,
    question:
        'Is there a direction you already know you refuse? Say it now, so six '
        'hours are not spent there.',
    whyItMatters:
        'The council never waits for input, so a refusal not stated here '
        'cannot be stated at all until the dossier arrives.',
  ),
  InterviewModule(
    id: 'unknowns',
    name: 'Declared unknowns',
    produces: BriefPart.unknowns,
    always: true,
    question:
        'What do you not yet know, and are content for the council to settle '
        'by assumption while you are away?',
    whyItMatters:
        'This is the run\'s licence to proceed without you. Every assumption '
        'it makes against one of these is marked in the dossier as a revisit '
        'point you can cheaply overturn.',
  ),
  InterviewModule(
    id: 'success-test',
    name: 'The test of a good session',
    produces: BriefPart.reason,
    always: true,
    question:
        'When you read the dossier, what would have to be in it for the '
        'session to have been worth the wait?',
    whyItMatters:
        'The coverage test is judged against this answer. Without it, '
        'completeness is whatever the council says it is.',
  ),
];

InterviewModule moduleById(String id) => interviewModules.firstWhere(
  (InterviewModule m) => m.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', 'no such interview module'),
);

/// Chooses and orders the modules for one interview.
///
/// Deterministic given a profile and the answers so far, which is what makes a
/// composed interview inspectable before it is put to a person. The order is
/// fixed by [interviewModules] rather than by the profile: a medium may make a
/// module essential, but it may not reorder the interview into its own shape,
/// because the client's experience of being interviewed should not vary with
/// a choice they made in the second question.
abstract final class InterviewComposer {
  /// The modules for a session in [profileId].
  ///
  /// [alsoInclude] carries modules an earlier answer made necessary — the
  /// interview is composed as it goes, not fixed at the start.
  static List<InterviewModule> compose({
    required String profileId,
    Set<String> alsoInclude = const <String>{},
  }) {
    final DomainProfile profile = profileById(profileId);
    final Set<String> wanted = <String>{
      for (final InterviewModule m in interviewModules)
        if (m.always) m.id,
      ...profile.essentialModules,
      ...alsoInclude,
    };
    return <InterviewModule>[
      for (final InterviewModule m in interviewModules)
        if (wanted.contains(m.id)) m,
    ];
  }

  /// Which parts of the brief a composed interview would fail to produce.
  ///
  /// Checked before the gate rather than after, because after the gate closes
  /// no answer may be re-elicited: a missing part discovered later cannot be
  /// fixed by asking, only by throwing the session away.
  static Set<BriefPart> unservedParts(List<InterviewModule> composed) {
    final Set<BriefPart> served = composed
        .map((InterviewModule m) => m.produces)
        .toSet();
    return BriefPart.values.toSet().difference(served);
  }
}

/// The same, or null.
///
/// For the places that only need to *print* a name: a session written by
/// another build, or read out of files a person edited, can name something
/// this catalog does not have — and a lookup that throws while a list is
/// being built takes the whole screen down, including every other session on
/// it. A run may still demand the strict one.
InterviewModule? moduleByIdOrNull(String id) {
  for (final InterviewModule m in interviewModules) {
    if (m.id == id) return m;
  }
  return null;
}
