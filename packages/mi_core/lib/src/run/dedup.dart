import 'package:meta/meta.dart';

import '../session/direction.dart';
import '../session/round.dart';

/// The result of testing one candidate against everything already on record.
@immutable
class DedupVerdict {
  const DedupVerdict.kept()
    : duplicateOf = null,
      similarity = 0,
      ruleId = DedupRule.currentRuleId;

  const DedupVerdict.rejected({
    required String this.duplicateOf,
    required this.similarity,
  }) : ruleId = DedupRule.currentRuleId;

  final String? duplicateOf;
  final double similarity;
  final String ruleId;

  bool get isDuplicate => duplicateOf != null;

  DedupRejection asRejection({
    required String candidateTitle,
    required String candidateSubstance,
  }) => DedupRejection(
    candidateTitle: candidateTitle,
    candidateSubstance: candidateSubstance,
    againstDirectionId: duplicateOf!,
    ruleId: ruleId,
    similarity: similarity,
  );
}

/// How the run decides that a proposal is something it already has.
///
/// This rule is load-bearing for run-until-dry: 'nothing new came back' is
/// exactly 'every proposal in this round was a duplicate', so a lax rule ends
/// runs early and a strict one runs them forever. It is deliberately
/// mechanical and deterministic — token overlap on the *substance* of a
/// direction, not on its title — because a judgement call here would put the
/// stopping condition inside the model's mood, and every stored session names
/// the rule it was judged under so two sessions are never silently compared
/// across a change to it.
///
/// The rule is compared on statement and mechanism together. Two proposers who
/// find the same move almost never choose the same title and almost always
/// describe the same mechanism, so the title is the one part of a direction
/// that carries no signal about whether it is new.
abstract final class DedupRule {
  /// Bumped whenever the rule changes, never edited in place. A stored session
  /// records this, so a dryness decision remains interpretable after the rule
  /// moves on.
  static const String currentRuleId = 'jaccard-substance-v1@0.62';

  static const double threshold = 0.62;

  static const Set<String> _stopWords = <String>{
    'a',
    'an',
    'and',
    'are',
    'as',
    'at',
    'be',
    'but',
    'by',
    'for',
    'from',
    'has',
    'have',
    'in',
    'into',
    'is',
    'it',
    'its',
    'of',
    'on',
    'or',
    'that',
    'the',
    'their',
    'them',
    'then',
    'they',
    'this',
    'to',
    'was',
    'were',
    'what',
    'when',
    'which',
    'who',
    'will',
    'with',
    'would',
    'you',
    'your',
    'not',
    'no',
    'so',
    'if',
    'than',
    'there',
    'these',
    'those',
    'we',
    'our',
  };

  /// Content words, lowercased, singularised crudely, stop words removed.
  static Set<String> tokens(String text) {
    final Iterable<String> raw = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((String w) => w.length > 2 && !_stopWords.contains(w));
    return raw
        .map(
          (String w) => w.endsWith('s') && !w.endsWith('ss')
              ? w.substring(0, w.length - 1)
              : w,
        )
        .toSet();
  }

  static double similarity(String a, String b) {
    final Set<String> ta = tokens(a);
    final Set<String> tb = tokens(b);
    if (ta.isEmpty || tb.isEmpty) return 0;
    final int shared = ta.intersection(tb).length;
    final int union = ta.union(tb).length;
    return shared / union;
  }

  /// Test [candidateSubstance] against everything already accepted.
  ///
  /// Compares against every direction rather than only against the current
  /// round's, because a round that re-proposes something from three rounds ago
  /// has not returned anything new either — and the opposite reading is how a
  /// run cycles forever between two neighbourhoods.
  static DedupVerdict test(
    String candidateSubstance,
    List<Direction> existing,
  ) {
    String? closest;
    double best = 0;
    for (final Direction d in existing) {
      final double s = similarity(candidateSubstance, d.substance);
      if (s > best) {
        best = s;
        closest = d.id;
      }
    }
    if (closest != null && best >= threshold) {
      return DedupVerdict.rejected(duplicateOf: closest, similarity: best);
    }
    return const DedupVerdict.kept();
  }
}
