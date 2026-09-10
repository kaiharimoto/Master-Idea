import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// One seat, one turn, before the sitting opens.
class Clerk implements CouncilTransport {
  Clerk(this.reply);
  final String reply;
  final List<CouncilTurn> seen = <CouncilTurn>[];

  @override
  Future<CouncilReply> ask(CouncilTurn turn) async {
    seen.add(turn);
    return CouncilReply(text: reply);
  }
}

void main() {
  final List<InterviewAnswer> answers = referenceInterview().answers;

  group('the clerk drafts the brief', () {
    test('and is shown every answer and every tier it may choose', () async {
      final Clerk clerk = Clerk(
        'mi-brief\nrestatement=One paragraph.\nend\n'
        'mi-scale\ntemplate=sitting\nreasoning=Two shapes.\nend',
      );
      await InterviewCounsel.seek(
        transport: clerk,
        answers: answers,
        profileId: 'software',
      );

      final String prompt = clerk.seen.single.prompt;
      for (final InterviewAnswer a in answers) {
        expect(
          prompt,
          contains(a.text),
          reason:
              'The restatement becomes the constitution of a deliberation the '
              'client will not attend, so it is drafted from what they said '
              'rather than from a summary of it.',
        );
      }
      for (final HarnessTemplate t in harnessTemplates) {
        expect(prompt, contains(t.id));
      }
      expect(clerk.seen.single.agent.roleId, 'clerk');
    });

    test('and its verdict names the seat that made it', () async {
      final InterviewAdvice? advice = await InterviewCounsel.seek(
        transport: Clerk(
          'mi-brief\nrestatement=One paragraph.\nend\n'
          'mi-scale\ntemplate=sitting\nreasoning=Two shapes.\nend',
        ),
        answers: answers,
        profileId: 'software',
      );

      expect(advice!.restatement, 'One paragraph.');
      expect(advice.verdict.templateId, 'sitting');
      expect(AgentInstance.parse(advice.verdict.by).roleId, 'clerk');
    });

    test(
      'a tier nobody offered falls back rather than being believed',
      () async {
        final InterviewAdvice? advice = await InterviewCounsel.seek(
          transport: Clerk(
            'mi-brief\nrestatement=One paragraph.\nend\n'
            'mi-scale\ntemplate=the-longest-one\nreasoning=Because.\nend',
          ),
          answers: answers,
          profileId: 'software',
        );

        expect(
          harnessTemplates.any(
            (HarnessTemplate t) => t.id == advice!.verdict.templateId,
          ),
          isTrue,
          reason:
              'A lenient parse here drifts towards the largest sitting, which '
              'is the one nobody should get by accident.',
        );
      },
    );

    test('a reply nothing can be read out of is not a draft', () async {
      expect(
        await InterviewCounsel.seek(
          transport: Clerk('Certainly! Here is the brief you asked for.'),
          answers: answers,
          profileId: 'software',
        ),
        isNull,
        reason:
            'Null means keep the composed draft. An empty restatement '
            'accepted here would be a constitution nobody wrote.',
      );
    });
  });

  group('with no council reachable', () {
    test('the composed draft is still a paragraph and a tier', () {
      final InterviewAdvice advice = InterviewCounsel.compose(answers);
      expect(advice.restatement, isNotEmpty);
      expect(advice.verdict.by, 'composed');
      expect(
        harnessTemplates.any(
          (HarnessTemplate t) => t.id == advice.verdict.templateId,
        ),
        isTrue,
      );
    });

    test('the client is never shown an empty box', () {
      expect(
        InterviewCounsel.compose(const <InterviewAnswer>[]).restatement,
        isEmpty,
        reason:
            'With nothing said there is nothing to restate — but the screen '
            'only reaches this after the interview, so it never happens.',
      );
    });
  });
}
