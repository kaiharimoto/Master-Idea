import '../council/angles.dart';
import '../council/dimensions.dart';
import '../council/profiles.dart';
import '../interview/interview_gate.dart';
import '../session/direction.dart';
import '../session/ledger.dart';
import '../session/rating.dart';

/// The four content failures the council must not commit.
///
/// They are written into the *generation* prompts as refusals, not only into
/// the review pass, because nobody is present during a six-hour run to catch
/// drift. A check that runs afterwards tells you the session was wasted; a
/// check that runs during it stops the waste.
const String antiPatterns = '''
REFUSE TO PRODUCE ANY OF THESE. Each is a failure, not a style preference.

- Restatement. The idea said back in other words and logged as new territory.
  If your proposal would still be true of the idea exactly as stated, it is
  not a direction.
- Consultant ambition. Grand vocabulary with no mechanism. If you cannot say
  how it would work in concrete terms, do not propose it.
- Diplomatic judgement. "It depends", or a verdict chosen so that nothing is
  ever actually rejected. A judgement that could not have gone the other way
  carries no information.
- Safe incrementalism. A feature request on the idea as stated rather than an
  alternative to it.
''';

/// Every prompt the council is sent.
///
/// Kept in one file so the anti-pattern refusals, the ordinal vocabularies and
/// the block grammar cannot drift apart between seats — three copies of the
/// grammar is three chances for a round to come back unreadable at hour four
/// with nobody watching.
abstract final class CouncilPrompts {
  static String propose({
    required ConfirmedBrief brief,
    required DomainProfile profile,
    required ExplorationAngle angle,
    required List<Territory> openGaps,
    required List<InterviewAnswer> answers,
    required int wanted,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('You are a prospector on a council deliberating one idea.')
      ..writeln(
        'You search from one angle only and you are blind to the other '
        'angles working this round. Do not try to cover the space; cover '
        'your angle.',
      )
      ..writeln()
      ..writeln('CONFIRMED BRIEF (constitution — nothing may contradict it)')
      ..writeln(brief.restatement)
      ..writeln()
      ..writeln('MEDIUM: ${profile.name}')
      ..writeln('A good direction here: ${profile.goodDirection}')
      ..writeln('Disqualifying here: ${profile.disqualifier}')
      ..writeln()
      ..writeln('YOUR ANGLE: ${angle.name} — ${angle.modality}')
      ..writeln(angle.instruction)
      ..writeln();

    if (answers.isNotEmpty) {
      b.writeln('WHAT THE CLIENT SAID (your directions must trace to one of');
      b.writeln('these answers, or to a named gap below)');
      for (final InterviewAnswer a in answers) {
        b.writeln('[${a.moduleId}] ${a.question}');
        b.writeln('  ${a.text}');
      }
      b.writeln();
    }

    if (openGaps.isNotEmpty) {
      b.writeln('OPEN GAPS IN THE MAP (naming one is the other legitimate');
      b.writeln('source for a direction)');
      for (final Territory t in openGaps) {
        b.writeln('[${t.id}] ${t.name} — ${t.description}');
      }
      b.writeln();
    }

    b
      ..writeln(antiPatterns)
      ..writeln()
      ..writeln('Propose up to $wanted directions. Fewer is correct if your')
      ..writeln('angle is exhausted — a round that returns nothing is how')
      ..writeln('this run learns it is finished, so padding it is sabotage.')
      ..writeln()
      ..writeln('Reply with blocks in exactly this form and nothing else:')
      ..writeln()
      ..writeln('mi-direction')
      ..writeln('cluster=<the question about the idea this answers>')
      ..writeln('ambition=conservative|ambitious|reckless')
      ..writeln('title=<a name, not a sentence>')
      ..writeln('statement=<the direction as a decision the client could take>')
      ..writeln('mechanism=<how it would actually work, concretely>')
      ..writeln('trace-answer=<module id>   (or trace-gap=<gap id>)')
      ..writeln('quote=<the exact phrase in that answer or gap>')
      ..writeln('end')
      ..writeln()
      ..writeln('If your angle has nothing left, reply with a single line:')
      ..writeln('mi-none');
    return b.toString();
  }

  static String challenge({
    required ConfirmedBrief brief,
    required Direction d,
  }) =>
      '''
You are a challenger on a council. You attack mechanisms. You do not rate, and
you do not propose alternatives.

CONFIRMED BRIEF (constitution)
${brief.restatement}

DIRECTION
Title: ${d.title}
Statement: ${d.statement}
Mechanism: ${d.mechanism}

Find the strongest reason this could not work as described. If the mechanism is
merely vocabulary — impressive words with no working part — say so plainly.

Reply with one block:

mi-challenge
attack=<the strongest objection, concretely>
fatal=yes|no
end
''';

  /// The rating prompt is built from [RatingContext] rather than from the
  /// direction, so the stripping that keeps a rater independent happens in one
  /// place and is stored with the verdict.
  static String rate(RatingContext context, RatingDimension dimension) =>
      '''
You are an assessor on a council. You judge one direction on one dimension and
nothing else. You do not know who proposed it and you must not speculate.

${context.shownText}

Your verdict is one word from the list above. Numerals are not permitted
anywhere in your reply, and neither is a hedge: if the direction deserves a
rejecting verdict, give it.

What this dimension exists to catch: ${dimension.catches}

Reply with one block:

mi-rating
verdict=<one word from the list>
because=<one or two sentences, specific to this direction>
end
''';

  static String dissent(
    RatingContext context,
    RatingDimension dimension,
    String verdict,
    String because,
  ) =>
      '''
You are the dissenting seat. An assessor has judged a direction and you read
the same material they did. You did not see who proposed it.

${context.shownText}

THE VERDICT ON RECORD
verdict=$verdict
because=$because

If you genuinely hold a different verdict, record it. If you agree, say so and
record nothing — dissent invented to look rigorous is worse than agreement,
because it makes every real disagreement cheaper.

Reply with one block, either:

mi-dissent
verdict=<one word from the same list>
because=<why the record is wrong>
end

or the single line:

mi-none
''';

  static String mapTerritory({
    required ConfirmedBrief brief,
    required DomainProfile profile,
    required List<Direction> found,
    required CoverageLedger ledger,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('You are the cartographer. You do not propose directions and')
      ..writeln('you do not rate them. You draw the map of the idea space and')
      ..writeln('say honestly what is not on it.')
      ..writeln()
      ..writeln('CONFIRMED BRIEF')
      ..writeln(brief.restatement)
      ..writeln()
      ..writeln('MEDIUM: ${profile.name}')
      ..writeln()
      ..writeln('WHAT THE COUNCIL HAS FOUND SO FAR')
      ..writeln();
    for (final Direction d in found) {
      b.writeln('- [${d.clusterName}] ${d.title}: ${d.statement}');
    }
    b
      ..writeln()
      ..writeln('TERRITORIES ALREADY ON THE MAP')
      ..writeln();
    for (final Territory t in ledger.territories) {
      b.writeln('- [${t.id}] ${t.name} (${t.status.name})');
    }
    b
      ..writeln()
      ..writeln('Write the territories this round settled, the territories you')
      ..writeln('are deliberately dropping with the reason, and the gaps that')
      ..writeln('are still open. A gap is a part of the idea space nobody has')
      ..writeln('entered — name it even when you have no idea what is in it,')
      ..writeln('because an unnamed gap is how a session claims completeness')
      ..writeln('it has not earned.')
      ..writeln()
      ..writeln('mi-territory')
      ..writeln('id=<short-kebab-id>')
      ..writeln('name=<a few words>')
      ..writeln('description=<one sentence on what lies there>')
      ..writeln('status=explored|dropped|gap')
      ..writeln('reason=<required when dropped: why it is not worth entering>')
      ..writeln('end');
    return b.toString();
  }

  static String integrate({
    required ConfirmedBrief brief,
    required List<Direction> selected,
  }) {
    final StringBuffer b = StringBuffer()
      ..writeln('You are the integrator. The client has selected these')
      ..writeln('directions. Say what they become together — not what each is')
      ..writeln('worth, which is already on the record.')
      ..writeln()
      ..writeln('CONFIRMED BRIEF')
      ..writeln(brief.restatement)
      ..writeln()
      ..writeln('THE SELECTION');
    for (final Direction d in selected) {
      b.writeln('[${d.id}] ${d.title}: ${d.statement}');
      b.writeln('  mechanism: ${d.mechanism}');
    }
    b
      ..writeln()
      ..writeln('Name every pair that reinforces and every pair that')
      ..writeln('conflicts. A conflict is not a reason to drop one — it is')
      ..writeln('what the client needs to know before committing.')
      ..writeln()
      ..writeln('mi-integration')
      ..writeln('becomes=<what the combined thing is, in one paragraph>')
      ..writeln('reinforces=<id>|<id>|<why>')
      ..writeln('conflicts=<id>|<id>|<what has to give>')
      ..writeln('end');
    return b.toString();
  }
}
