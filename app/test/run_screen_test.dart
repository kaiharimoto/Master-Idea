import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/screens/run.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:master_idea/src/store/sitting.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import 'library_test.dart' show interview;
import 'support/scripted_council.dart';

/// The phone's whole sitting, which had no test at all.
///
/// Everything here happens on the handover route, because that is the one a
/// person has to work: the turn goes out by hand, the reply is read back
/// before it is accepted, and the sitting can be stopped.
void main() {
  /// A tall view, so the sitting screen's whole column is on screen. The
  /// default 800x600 puts the reply field and its buttons below the fold,
  /// where a tap lands on nothing and reads as a passing test.
  void roomToWork(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<(Library, Sitting, Session)> ready(WidgetTester tester) async {
    roomToWork(tester);
    final Library library = Library(inMemory: true);
    await library.load();
    final Session session = await library.begin(interview());
    final Sitting sitting = Sitting(
      library,
      canDrive: false,
      open: (_, _) async => ScriptedCouncil(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MiTheme(
          colors: MiColors.light,
          isDark: false,
          child: Scaffold(
            body: RunScreen(
              library: library,
              sitting: sitting,
              session: session,
              onFinished: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (library, sitting, session);
  }

  testWidgets('a turn is carried out, read back, and accepted', (
    WidgetTester tester,
  ) async {
    final (Library library, Sitting sitting, Session session) = await ready(
      tester,
    );

    expect(find.text('Open the sitting'), findsOneWidget);
    await tester.tap(find.text('Open the sitting'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Copy this turn'),
      findsOneWidget,
      reason: 'On a phone the council is reached by hand, one turn at a time.',
    );
    expect(find.text('Stop the sitting'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'mi-none');
    await tester.tap(find.text('Read it back'));
    await tester.pump();

    expect(
      find.textContaining('mi-none'),
      findsWidgets,
      reason:
          'A reply is read before it is accepted: the run cannot tell a '
          'truncated paste from a seat with nothing to say, and one of those '
          'is what takes a run to dryness.',
    );
    expect(find.text('Accept it'), findsOneWidget);
    expect(find.text('Paste again'), findsOneWidget);

    await tester.tap(find.text('Accept it'));
    await tester.pump();
    sitting.stop();
    await tester.pump();
    expect(library.open, isNotNull);
  });

  testWidgets('the sitting can be paused and continued from the screen', (
    WidgetTester tester,
  ) async {
    final (Library library, Sitting sitting, Session session) = await ready(
      tester,
    );
    await tester.tap(find.text('Open the sitting'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Pause the sitting'), findsOneWidget);
    expect(find.text('Copy this turn'), findsOneWidget);

    await tester.tap(find.text('Pause the sitting'));
    await tester.pump();

    // The status tag sets its text in capitals.
    expect(find.text('PAUSED BY YOU'), findsOneWidget);
    expect(find.textContaining('Nothing new is being sent'), findsOneWidget);
    expect(find.text('Continue the sitting'), findsOneWidget);
    expect(
      find.text('Stop the sitting'),
      findsOneWidget,
      reason: 'Pausing must not take away the way out.',
    );
    expect(
      find.text('Copy this turn'),
      findsOneWidget,
      reason:
          'A turn already out is still out: pausing stops new turns, it does '
          'not take back the one on screen.',
    );

    await tester.tap(find.text('Continue the sitting'));
    await tester.pump();
    expect(find.text('Pause the sitting'), findsOneWidget);
    expect(find.text('PAUSED BY YOU'), findsNothing);

    sitting.stop();
    await tester.pump();
  });

  testWidgets('an unreadable paste says so instead of being accepted quietly', (
    WidgetTester tester,
  ) async {
    await ready(tester);
    await tester.tap(find.text('Open the sitting'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).first,
      'Certainly! Here is my answer:',
    );
    await tester.tap(find.text('Read it back'));
    await tester.pump();

    expect(
      find.textContaining('Nothing the council could use'),
      findsOneWidget,
    );
  });

  testWidgets('a session the council is not sitting on says whose it is', (
    WidgetTester tester,
  ) async {
    roomToWork(tester);
    final Library library = Library(inMemory: true);
    await library.load();
    final Session first = await library.begin(interview());
    final Session second = await library.begin(interview());
    final Sitting sitting = Sitting(
      library,
      canDrive: false,
      open: (_, _) async => ScriptedCouncil(),
    );
    unawaited(sitting.begin(first, library.settings));

    await tester.pumpWidget(
      MaterialApp(
        home: MiTheme(
          colors: MiColors.light,
          isDark: false,
          child: Scaffold(
            body: RunScreen(
              library: library,
              sitting: sitting,
              session: second,
              onFinished: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('sitting on another session'), findsOneWidget);
    sitting.stop();
    await tester.pump();
  });
}
