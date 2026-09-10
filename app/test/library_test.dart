import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:mi_core/mi_core.dart';

InterviewRecord interview({
  bool withUnknowns = true,
  String templateId = 'hearing',
}) {
  final DateTime at = DateTime.utc(2026, 3, 1, 9);
  final List<InterviewModule> composed = InterviewComposer.compose(
    profileId: 'essay',
  );
  return InterviewRecord(
    profileId: 'essay',
    moduleOrder: <String>[for (final InterviewModule m in composed) m.id],
    answers: <InterviewAnswer>[
      for (final InterviewModule m in composed)
        InterviewAnswer(
          moduleId: m.id,
          question: m.question,
          text: 'What the client said about ${m.name.toLowerCase()}.',
          at: at,
        ),
    ],
    brief: ConfirmedBrief(
      restatement:
          'An essay arguing that unattended machine work is only trustworthy '
          'when its reasoning is auditable afterwards.',
      approvedAt: at,
    ),
    unknowns: withUnknowns
        ? const <DeclaredUnknown>[
            DeclaredUnknown(
              id: 'u-length',
              question: 'How long it should run.',
              licence: 'Assume whatever the argument needs, and mark it.',
            ),
          ]
        : const <DeclaredUnknown>[],
    verdict: ScaleVerdict(
      templateId: templateId,
      reasoning: 'One claim, one sitting.',
    ),
    closedAt: at,
  );
}

void main() {
  // Plain `test`, not `testWidgets`: file I/O never completes inside the
  // tester's fake-async zone, and the library is in memory for the same
  // reason.
  test('a closed interview opens a session', () async {
    final Library library = Library(inMemory: true);
    await library.load();

    final Session s = await library.begin(interview());

    expect(library.sessions, hasLength(1));
    expect(library.open, isNotNull);
    expect(s.title, isNotEmpty);
    expect(s.taskId, isNot(contains(' ')));
    expect(s.interview.brief.restatement, contains('auditable'));
    expect(s.manifest.templateId, 'hearing');
  });

  test('a session with no declared unknowns is refused', () async {
    final Library library = Library(inMemory: true);
    await library.load();

    expect(
      () => library.begin(interview(withUnknowns: false)),
      throwsA(isA<StateError>()),
      reason:
          'The sitting never waits on input, so a run with no licence to '
          'settle anything stalls the first time it needs to — with nobody '
          'there to notice.',
    );
    expect(library.sessions, isEmpty);
  });

  test('the title is short enough to recognise in a list', () async {
    final Library library = Library(inMemory: true);
    await library.load();
    final Session s = await library.begin(interview());
    expect(s.title.length, lessThanOrEqualTo(57));
  });

  test('closing a session leaves the app on its opening question', () async {
    final Library library = Library(inMemory: true);
    await library.load();
    await library.begin(interview());
    library.close();
    expect(
      library.open,
      isNull,
      reason:
          'There is no blank canvas to return to: with nothing open the app '
          'is a question again.',
    );
  });
}
