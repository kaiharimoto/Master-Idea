import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../council/dimensions.dart';
import 'direction.dart';

/// Exactly what an assessor was shown before it gave a verdict.
///
/// Independent rating is a hard invariant, and it is not satisfied by seating
/// a different agent: an assessor told *who* proposed a direction, or handed
/// the proposer's case for it, is rating the advocacy. So the context is
/// **constructed by stripping**, here, in one place — [forDirection] is the
/// only way to build one — and the text it produces is stored with the rating
/// so an auditor can read what the rater read.
@immutable
class RatingContext {
  const RatingContext._({
    required this.shownText,
    required this.carriedProposerIdentity,
    required this.carriedAdvocacy,
  });

  /// The whole of what the assessor saw.
  final String shownText;

  /// Both false for anything [forDirection] builds. Present as fields so that
  /// a session which somehow contains a context built another way is
  /// *detectable* rather than merely unlikely.
  final bool carriedProposerIdentity;
  final bool carriedAdvocacy;

  String get digest =>
      sha256.convert(utf8.encode(shownText)).toString().substring(0, 16);

  /// Build the context for judging [d] on [dimension].
  ///
  /// Carries the direction's substance and the constitution it must hold to,
  /// and nothing about where it came from: not the proposer, not the angle
  /// (an angle name is a hint about the proposer's lens), not the round.
  static RatingContext forDirection(
    Direction d,
    RatingDimension dimension, {
    required String briefRestatement,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('CONFIRMED BRIEF (constitution)')
      ..writeln(briefRestatement)
      ..writeln()
      ..writeln('DIRECTION UNDER JUDGEMENT')
      ..writeln('Title: ${d.title}')
      ..writeln('Statement: ${d.statement}')
      ..writeln('Mechanism: ${d.mechanism}')
      ..writeln()
      ..writeln('QUESTION')
      ..writeln(dimension.question)
      ..writeln()
      ..writeln('ANSWER WITH EXACTLY ONE OF')
      ..writeln(dimension.vocabulary.rungs.join(', '));
    return RatingContext._(
      shownText: b.toString(),
      carriedProposerIdentity: false,
      carriedAdvocacy: false,
    );
  }

  /// Rebuild a stored context. Used by the invariant suite, which must be able
  /// to work from files alone.
  static RatingContext stored(Map<String, Object?> j) => RatingContext._(
    shownText: '${j['shownText']}',
    carriedProposerIdentity: j['carriedProposerIdentity'] == true,
    carriedAdvocacy: j['carriedAdvocacy'] == true,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'shownText': shownText,
    'digest': digest,
    'carriedProposerIdentity': carriedProposerIdentity,
    'carriedAdvocacy': carriedAdvocacy,
  };
}

/// A minority verdict, held rather than averaged.
///
/// A dissent must be attributable to a seat that actually held it. Dissent
/// invented to satisfy a check that dissent exists is worse than none: it
/// looks like rigour and carries no information, which is the diplomatic
/// rating failure arriving by the opposite door.
@immutable
class Dissent {
  const Dissent({
    required this.by,
    required this.verdict,
    required this.because,
  });

  /// The agent instance that held it.
  final String by;

  /// A rung of the same vocabulary as the rating it dissents from.
  final String verdict;

  final String because;

  Map<String, Object?> toJson() => <String, Object?>{
    'by': by,
    'verdict': verdict,
    'because': because,
  };

  static Dissent fromJson(Map<String, Object?> j) => Dissent(
    by: '${j['by']}',
    verdict: '${j['verdict']}',
    because: '${j['because']}',
  );
}

/// One verdict, on one direction, on one dimension, by one agent.
@immutable
class Rating {
  const Rating({
    required this.directionId,
    required this.dimensionId,
    required this.verdict,
    required this.vocabularyId,
    required this.ratedBy,
    required this.context,
    required this.because,
    this.dissents = const <Dissent>[],
  });

  final String directionId;
  final String dimensionId;

  /// An ordinal word. Never a numeral, anywhere, in either client.
  final String verdict;

  /// Which closed vocabulary the word was drawn from, named on the record so
  /// a verdict read in isolation still means something.
  final String vocabularyId;

  /// The agent instance that gave it. Must not be the direction's proposer.
  final String ratedBy;

  final RatingContext context;

  /// The assessor's reason, in its own words.
  final String because;

  final List<Dissent> dissents;

  RatingVocabulary get vocabulary => vocabularyById(vocabularyId);

  bool get rejects => vocabulary.rejects(verdict);

  bool get isDisputed => dissents.isNotEmpty;

  /// How far apart the majority and the furthest dissent are, in rungs. Used
  /// only to order the dossier so the most contested directions are read
  /// first — never rendered, because that would be a numeral in a rating.
  int get spread {
    int worst = vocabulary.rankOf(verdict);
    int best = worst;
    for (final Dissent d in dissents) {
      final int r = vocabulary.rankOf(d.verdict);
      if (r < worst) worst = r;
      if (r > best) best = r;
    }
    return best - worst;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'directionId': directionId,
    'dimensionId': dimensionId,
    'verdict': verdict,
    'vocabularyId': vocabularyId,
    'ratedBy': ratedBy,
    'because': because,
    'context': context.toJson(),
    'dissents': dissents.map((Dissent d) => d.toJson()).toList(),
  };

  static Rating fromJson(Map<String, Object?> j) => Rating(
    directionId: '${j['directionId']}',
    dimensionId: '${j['dimensionId']}',
    verdict: '${j['verdict']}',
    vocabularyId: '${j['vocabularyId']}',
    ratedBy: '${j['ratedBy']}',
    because: '${j['because']}',
    context: RatingContext.stored(j['context']! as Map<String, Object?>),
    dissents: (j['dissents'] as List<Object?>? ?? const <Object?>[])
        .map((Object? e) => Dissent.fromJson(e! as Map<String, Object?>))
        .toList(),
  );
}
