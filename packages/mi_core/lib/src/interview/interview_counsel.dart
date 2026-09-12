import '../council/profiles.dart';
import '../council/roles.dart';
import '../council/templates.dart';
import '../run/council_prompts.dart';
import '../run/council_turn.dart';
import 'interview_gate.dart';

/// What the clerk came back with.
class InterviewAdvice {
  const InterviewAdvice({
    required this.restatement,
    required this.verdict,
    required this.by,
  });

  /// The brief as the council would put it. **Not** the confirmed brief: it is
  /// the client's approval that makes it constitution, and until they have
  /// given it this is a draft like any other.
  final String restatement;

  final ScaleVerdict verdict;

  /// The seat that drafted it.
  final String by;
}

/// The one turn the council takes before the sitting opens.
///
/// The interview gate has always documented the scale verdict as a judgement
/// the model makes from the vision rather than a menu the client picks from,
/// and the confirmed brief as *the tool's* restatement of the idea. What
/// actually shipped was string concatenation and a keyword search over the
/// appetite answer: it joined four raw answers with full stops and read the
/// word "year". That is a placeholder, and a placeholder in this position is
/// load-bearing — the restatement becomes the constitution of a deliberation
/// the client will not attend.
///
/// [compose] is what it did, kept deliberately: it is what the client sees the
/// instant the last question is answered, and it is what a device with no
/// council reachable falls back to. [seek] is the council doing it properly.
/// The client's own edit outranks both.
abstract final class InterviewCounsel {
  /// Ask the clerk. Null when the reply carried nothing usable, which is a
  /// reason to keep the composed draft rather than to stop.
  static Future<InterviewAdvice?> seek({
    required CouncilTransport transport,
    required List<InterviewAnswer> answers,
    required String profileId,
  }) async {
    if (answers.isEmpty) return null;
    const AgentInstance clerk = AgentInstance(
      roleId: 'clerk',
      round: 0,
      ordinal: 1,
    );
    final CouncilReply reply = await transport.ask(
      CouncilTurn(
        agent: clerk,
        purpose: 'restate',
        prompt: CouncilPrompts.restate(
          answers: answers,
          profile: profileById(profileId),
          templates: harnessTemplates,
        ),
        conversation: 'restate',
      ),
    );

    final ParsedReply parsed = CouncilReplyParser.parse(reply.text);
    final List<CouncilBlock> briefs = parsed.of('mi-brief');
    final List<CouncilBlock> scales = parsed.of('mi-scale');
    if (briefs.isEmpty) return null;

    final String restatement = briefs.first.get('restatement').trim();
    if (restatement.isEmpty) return null;

    // A template id nobody offered is not a tier. Falling back to the composed
    // verdict rather than to the largest sitting, which is what a lenient
    // parse would drift towards.
    final String? id = scales.isEmpty ? null : scales.first.get('template');
    final bool known = harnessTemplates.any((HarnessTemplate t) => t.id == id);
    return InterviewAdvice(
      restatement: restatement,
      verdict: known
          ? ScaleVerdict(
              templateId: id!,
              reasoning: scales.first.get('reasoning'),
              by: clerk.id,
            )
          : compose(answers).verdict,
      by: clerk.id,
    );
  }

  /// The draft the client sees immediately, and the answer where no council
  /// can be reached.
  ///
  /// The tool moves first here as everywhere: a paragraph to correct, never an
  /// empty box to fill.
  static InterviewAdvice compose(List<InterviewAnswer> answers) {
    String said(String id) {
      for (final InterviewAnswer a in answers) {
        if (a.moduleId == id) return a.text.trim();
      }
      return '';
    }

    final String idea = said('raw-idea');
    final String audience = said('audience');
    final String ceiling = said('ceiling');
    final String alternatives = said('existing-alternatives');
    final String restatement = <String>[
      idea,
      if (audience.isNotEmpty) 'It is for $audience',
      if (alternatives.isNotEmpty) 'It exists alongside $alternatives',
      if (ceiling.isNotEmpty) 'At its highest, $ceiling',
    ].join('. ').replaceAll('..', '.');

    return InterviewAdvice(
      restatement: restatement,
      verdict: _tierFrom(said('appetite'), ceiling),
      by: 'composed',
    );
  }

  static ScaleVerdict _tierFrom(String appetite, String ceiling) {
    final String a = appetite.toLowerCase();
    bool says(List<String> words) => words.any(a.contains);

    if (says(<String>['year', 'life', 'career', 'decade'])) {
      return const ScaleVerdict(
        templateId: 'assize',
        reasoning:
            'You described this as work measured in years. An idea somebody '
            'intends to spend that long on is worth the longest sitting the '
            'council holds.',
        by: 'composed',
      );
    }
    if (says(<String>['month', 'season', 'summer'])) {
      return const ScaleVerdict(
        templateId: 'session',
        reasoning:
            'Months of work, and the medium is still genuinely open. That is '
            'a sitting rather than a hearing.',
        by: 'composed',
      );
    }
    if (says(<String>['week', 'fortnight'])) {
      return const ScaleVerdict(
        templateId: 'sitting',
        reasoning:
            'Weeks of work: more than one plausible shape, but not an open '
            'field.',
        by: 'composed',
      );
    }
    return ScaleVerdict(
      templateId: 'hearing',
      reasoning: ceiling.length > 240
          ? 'You describe an afternoon\'s work with a ceiling far above it. '
                'The council starts with a hearing and you can convene again.'
          : 'An afternoon or a few days of work. A hearing is the right size, '
                'and a sitting that goes dry early is a sitting that was too '
                'large.',
      by: 'composed',
    );
  }
}
