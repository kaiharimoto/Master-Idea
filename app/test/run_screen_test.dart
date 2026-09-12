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

  /// A session as it is on disk after two rounds: what the client reopened.
  Session withRounds(Session base) {
    DateTime at(int m) => DateTime.utc(2026, 3, 1, 9, m);
    return base.copyWith(
      directions: <Direction>[
        for (int i = 1; i <= 3; i++)
          Direction(
            id: 'd-000$i',
            clusterId: 'what-it-is-for',
            clusterName: 'What the thing is for',
            ambition: Ambition.ambitious,
            title: 'Sell the archive, keep the index',
            statement: 'Publish the lot and charge for finding things in it.',
            mechanism: 'The archive is mirrored; the index is regenerated.',
            proposedBy: 'prospector#1.$i',
            round: 1,
            angleId: 'inversion',
            trace: const TraceLink(answerModuleId: 'raw-idea', quote: 'said'),
          ),
      ],
      rounds: <RoundRecord>[
        RoundRecord(
          number: 1,
          angleSet: const <String>['inversion', 'first-principles'],
          returns: const <AngleReturn>[
            AngleReturn(
              angleId: 'inversion',
              by: 'prospector#1.1',
              proposedIds: <String>['a', 'b', 'c', 'd'],
              keptIds: <String>['d-0001', 'd-0002', 'd-0003'],
            ),
          ],
          rejections: const <DedupRejection>[],
          refusals: const <Refusal>[],
          newDirectionIds: const <String>['d-0001', 'd-0002', 'd-0003'],
          gapsNamed: const <String>['t-gap-1'],
          startedAt: at(0),
          endedAt: at(40),
        ),
        RoundRecord(
          number: 2,
          angleSet: const <String>['inversion', 'first-principles'],
          returns: const <AngleReturn>[],
          rejections: const <DedupRejection>[],
          refusals: const <Refusal>[],
          newDirectionIds: const <String>[],
          gapsNamed: const <String>[],
          startedAt: at(40),
          endedAt: at(70),
        ),
      ],
    );
  }

  testWidgets('a sitting that is not running still shows what it did', (
    WidgetTester tester,
  ) async {
    roomToWork(tester);
    final Library library = Library(inMemory: true);
    await library.load();
    final Session opened = await library.begin(interview());
    await library.save(withRounds(opened));
    final Sitting sitting = Sitting(
      library,
      canDrive: true,
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
              session: library.open!,
              onFinished: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Nothing yet.'),
      findsNothing,
      reason:
          'The screen read the run\'s event list, which begin() clears and a '
          'restart throws away. A client who reopened the app after two '
          'rounds, ninety-six directions and twelve hundred model calls was '
          'told the council had done nothing.',
    );
    expect(find.text('Round 1'), findsOneWidget);
    expect(
      find.textContaining('Inversion'),
      findsWidgets,
      reason:
          'The record stores angle ids. A client reading '
          '"constraint-tightening" is reading a machine\'s noun, and the '
          'catalog has had a name for it all along.',
    );
    expect(
      find.text('Sell the archive, keep the index'),
      findsWidgets,
      reason:
          'A counter climbing tells the client the machine is running. The '
          'titles tell them what it is running toward.',
    );
  });

  testWidgets('what is still owed is a floor and never a forecast', (
    WidgetTester tester,
  ) async {
    roomToWork(tester);
    final Library library = Library(inMemory: true);
    await library.load();
    final Session opened = await library.begin(interview());
    await library.save(withRounds(opened));
    final Sitting sitting = Sitting(
      library,
      canDrive: true,
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
              session: library.open!,
              onFinished: () {},
              onOpenSettings: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('CANNOT END BEFORE'), findsOneWidget);
    for (final Text t in tester.widgetList<Text>(find.byType(Text))) {
      final String said = (t.data ?? '').toLowerCase();
      for (final String banned in <String>['%', 'estimate', 'eta']) {
        expect(
          said,
          isNot(contains(banned)),
          reason:
              'A run that can be ended by a counter will be, and "ran until '
              'the number" would then be written down as "ran dry". A screen '
              'is where a ceiling sneaks back in wearing a percentage.',
        );
      }
    }
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
