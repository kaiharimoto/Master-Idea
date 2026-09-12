import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/screens/interview_proceeding.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:master_idea/src/store/sitting.dart';
import 'package:mi_design/mi_design.dart';

import 'support/scripted_council.dart';

/// The one stage where all of the client's work happens.
void main() {
  Future<(Library, InterviewDraft)> proceeding(
    WidgetTester tester, {
    bool canDrive = true,
  }) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Library library = Library(inMemory: true);
    await library.load();
    final InterviewDraft draft = InterviewDraft(
      rawIdea: 'An essay about auditability.',
    );
    final Sitting sitting = Sitting(
      library,
      canDrive: canDrive,
      open: (_, _) async => ScriptedCouncil(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MiTheme(
          colors: MiColors.light,
          isDark: false,
          child: Scaffold(
            body: InterviewProceeding(
              draft: draft,
              library: library,
              sitting: sitting,
              onAbandoned: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (library, draft);
  }

  testWidgets('an answer can be taken back and given again', (
    WidgetTester tester,
  ) async {
    final (Library library, InterviewDraft draft) = await proceeding(tester);

    await tester.tap(find.text('Song or composition'));
    await tester.pumpAndSettle();
    expect(draft.answers['medium'], 'Song or composition');

    await tester.tap(find.text('What has been settled'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change').first);
    await tester.pumpAndSettle();

    expect(
      draft.answers.containsKey('raw-idea'),
      isFalse,
      reason:
          'A typo in question three should not cost fifteen answers to fix; '
          'nothing is frozen until the gate closes over it.',
    );
  });

  testWidgets('every answer is on disk as it is given', (
    WidgetTester tester,
  ) async {
    final (Library library, InterviewDraft draft) = await proceeding(tester);

    await tester.tap(find.text('Essay or argument'));
    await tester.pumpAndSettle();

    final Map<String, Object?>? kept = library.draft;
    expect(kept, isNotNull);
    final InterviewDraft again = InterviewDraft.fromJson(kept!);
    expect(again.answers['raw-idea'], 'An essay about auditability.');
    expect(
      again.profileId,
      isNotNull,
      reason:
          'A phone reclaiming the app in the background used to lose the '
          'whole interview, with nothing on disk to resume from.',
    );
  });

  testWidgets('the gate says what it still wants before it is pressed', (
    WidgetTester tester,
  ) async {
    final (Library library, InterviewDraft draft) = await proceeding(
      tester,
      canDrive: false,
    );

    // Answer everything, the way the client does.
    await tester.tap(find.text('Essay or argument'));
    await tester.pumpAndSettle();
    while (draft.pending != null) {
      await tester.enterText(
        find.byType(TextField).first,
        'What the client said about this, at some length and specifically.',
      );
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Approve the brief'), findsOneWidget);
    expect(
      find.textContaining('no licence to settle anything'),
      findsOneWidget,
      reason:
          'The gate refuses an interview with nothing declared unknown, and '
          'the client used to discover that only by pressing the button.',
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'What you do not know.'),
      'Whether it should be one essay or three.',
    );
    await tester.tap(find.text('Declare it'));
    await tester.pumpAndSettle();

    expect(find.textContaining('no licence to settle anything'), findsNothing);
    expect(draft.unknowns, hasLength(1));

    await tester.tap(find.text('Withdraw'));
    await tester.pumpAndSettle();
    expect(
      draft.unknowns,
      isEmpty,
      reason: 'A typo in the run\'s licence used to be permanent.',
    );
  });

  testWidgets('the clerk can be asked by hand where there is no CLI', (
    WidgetTester tester,
  ) async {
    final (Library library, InterviewDraft draft) = await proceeding(
      tester,
      canDrive: false,
    );

    await tester.tap(find.text('Essay or argument'));
    await tester.pumpAndSettle();
    while (draft.pending != null) {
      await tester.enterText(
        find.byType(TextField).first,
        'What the client said about this, at some length and specifically.',
      );
      await tester.tap(find.text('Record'));
      await tester.pumpAndSettle();
    }

    expect(
      find.textContaining('Composed from your answers'),
      findsOneWidget,
      reason:
          'The tool moves first: a paragraph to correct, never an empty box, '
          'and never a wait before there is anything on screen.',
    );

    await tester.tap(find.text('Ask the council'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Copy this turn'),
      findsOneWidget,
      reason:
          'On a phone the clerk is one more turn carried by hand — offered, '
          'not automatic, because it comes before the client has agreed to '
          'carry hundreds.',
    );
  });
}
