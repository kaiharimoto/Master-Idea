import 'package:meta/meta.dart';

/// A closed, ordered set of verdict words.
///
/// Ratings in this tool are **ordinal words, never numerals**. A number invites
/// three things the council must not do: averaging (which is how dissent
/// disappears), arithmetic across incommensurable dimensions, and the false
/// precision of a score to one decimal place on a judgement made by reading a
/// paragraph. The words are ordered, so a rating can still be compared and
/// sorted — the ordering lives here, in code, and never reaches the page.
///
/// Vocabularies are committed before the first review cycle and never
/// reworded afterwards; `critics/vocabularies.md` is the copy the critics are
/// given, and `families_test.dart` asserts the two agree.
@immutable
class RatingVocabulary {
  const RatingVocabulary({
    required this.id,
    required this.rungs,
    required this.rejectAtOrBelow,
  });

  final String id;

  /// Worst first. The order is the only quantitative thing about a rating.
  final List<String> rungs;

  /// The highest rung that still counts as a rejection.
  ///
  /// A vocabulary with no rejecting rung cannot reject anything, which is
  /// exactly the diplomatic-rating failure written down as a data structure.
  final String rejectAtOrBelow;

  int rankOf(String word) {
    final int i = rungs.indexOf(word);
    if (i < 0) {
      throw ArgumentError.value(word, 'word', 'not a rung of vocabulary $id');
    }
    return i;
  }

  bool contains(String word) => rungs.contains(word);

  /// True when this verdict is a rejection rather than a reservation.
  bool rejects(String word) => rankOf(word) <= rankOf(rejectAtOrBelow);

  String get worst => rungs.first;
  String get best => rungs.last;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'rungs': rungs,
    'rejectAtOrBelow': rejectAtOrBelow,
  };
}

const RatingVocabulary vocabStrength = RatingVocabulary(
  id: 'strength',
  rungs: <String>['unfounded', 'weak', 'sound', 'strong', 'commanding'],
  rejectAtOrBelow: 'weak',
);

const RatingVocabulary vocabPresence = RatingVocabulary(
  id: 'presence',
  rungs: <String>['absent', 'gestured', 'specified', 'demonstrated'],
  rejectAtOrBelow: 'gestured',
);

const RatingVocabulary vocabDistance = RatingVocabulary(
  id: 'distance',
  rungs: <String>['restatement', 'variant', 'departure', 'break'],
  rejectAtOrBelow: 'restatement',
);

const RatingVocabulary vocabPlausibility = RatingVocabulary(
  id: 'plausibility',
  rungs: <String>[
    'unattemptable',
    'doubtful',
    'attemptable',
    'straightforward',
  ],
  rejectAtOrBelow: 'unattemptable',
);

const RatingVocabulary vocabConsequence = RatingVocabulary(
  id: 'consequence',
  rungs: <String>['inert', 'marginal', 'material', 'decisive'],
  rejectAtOrBelow: 'inert',
);

const RatingVocabulary vocabFit = RatingVocabulary(
  id: 'fit',
  rungs: <String>['contradicts', 'strains', 'consistent', 'fulfils'],
  rejectAtOrBelow: 'contradicts',
);

const List<RatingVocabulary> ratingVocabularies = <RatingVocabulary>[
  vocabStrength,
  vocabPresence,
  vocabDistance,
  vocabPlausibility,
  vocabConsequence,
  vocabFit,
];

RatingVocabulary vocabularyById(String id) => ratingVocabularies.firstWhere(
  (RatingVocabulary v) => v.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', 'no such vocabulary'),
);

/// One axis a direction is judged on, by an agent that did not propose it.
///
/// Dimensions are distinguished by **the failure each would catch**. Two that
/// would rise and fall together count as one axis wearing two names, and buy
/// nothing but a longer dossier. Each dimension below names a specific
/// anti-pattern or defect it is the council's only defence against.
@immutable
class RatingDimension {
  const RatingDimension({
    required this.id,
    required this.name,
    required this.question,
    required this.catches,
    required this.vocabulary,
  });

  final String id;
  final String name;

  /// The question put to the assessor. It is asked without the proposer's
  /// identity or advocacy attached — see `RatingContext`.
  final String question;

  /// The failure this axis exists to catch. Unique across the catalog.
  final String catches;

  final RatingVocabulary vocabulary;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'vocabulary': vocabulary.id,
  };
}

/// The dimension catalog. The floor is five; six are here, and the sixth —
/// fidelity — exists because the confirmed brief is constitution: a brilliant
/// direction that contradicts what the client approved is out of order, and
/// nothing else on the list would say so.
const List<RatingDimension> ratingDimensions = <RatingDimension>[
  RatingDimension(
    id: 'distinctness',
    name: 'Distinctness',
    question:
        'How far is this from the idea as stated and from the directions '
        'already before the council?',
    catches:
        'Restatement disguised as a direction — the idea rephrased and logged '
        'as new territory covered.',
    vocabulary: vocabDistance,
  ),
  RatingDimension(
    id: 'mechanism',
    name: 'Mechanism',
    question: 'Can this direction say how it would actually work?',
    catches:
        'Consultant ambition — grand vocabulary with nothing underneath it.',
    vocabulary: vocabPresence,
  ),
  RatingDimension(
    id: 'ambition',
    name: 'Ambition',
    question:
        'How much does this raise the ceiling of what the idea could become?',
    catches:
        'Safe incrementalism — a feature request on the idea as stated rather '
        'than an alternative to it.',
    vocabulary: vocabStrength,
  ),
  RatingDimension(
    id: 'feasibility',
    name: 'Feasibility',
    question:
        'Could this be attempted at all by the person who brought the idea?',
    catches:
        'A reckless option with no attemptable form, which reads as range and '
        'delivers nothing.',
    vocabulary: vocabPlausibility,
  ),
  RatingDimension(
    id: 'consequence',
    name: 'Consequence',
    question: 'If this direction were taken, what would actually change?',
    catches:
        'The novel, workable direction that alters nothing about the result.',
    vocabulary: vocabConsequence,
  ),
  RatingDimension(
    id: 'fidelity',
    name: 'Fidelity',
    question: 'Does this hold to the confirmed brief the client approved?',
    catches:
        'A direction that quietly overturns the constitution the client '
        'signed, where only the client may do that.',
    vocabulary: vocabFit,
  ),
];

RatingDimension dimensionById(String id) => ratingDimensions.firstWhere(
  (RatingDimension d) => d.id == id,
  orElse: () => throw ArgumentError.value(id, 'id', 'no such rating dimension'),
);
