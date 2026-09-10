import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/screens/assembly.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:master_idea/src/store/sitting.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import 'library_test.dart' show interview;
import 'support/scripted_council.dart';

/// Where the client presides, and the one screen that decides what leaves.
void main() {
  Future<(Library, Sitting, Session)> assembled(
    WidgetTester tester, {
    bool canDrive = true,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Library library = Library(inMemory: true);
    await library.load();
    final Session opened = await library.begin(interview());

    // A real sitting, so the directions on screen are ones a council actually
    // proposed and rated rather than values assembled by hand.
    final Sitting run = Sitting(
      library,
      canDrive: true,
      open: (_, _) async => ScriptedCouncil(),
    );
    await run.begin(opened, library.settings);

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
            body: AssemblyScreen(
              library: library,
              sitting: sitting,
              session: library.open!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return (library, sitting, library.open!);
  }

  testWidgets('changing the selection drops what it made', (
    WidgetTester tester,
  ) async {
    final (Library library, Sitting sitting, Session session) = await assembled(
      tester,
    );
    expect(session.directions, isNotEmpty);

    await tester.tap(find.text(session.directions.first.title));
    await tester.pump();
    expect(library.open!.selection, hasLength(1));

    await tester.tap(find.text('Compute what they become'));
    await tester.pump();
    await tester.pump();
    expect(library.open!.integration, isNotNull);
    expect(
      library.open!.pitch,
      isNotEmpty,
      reason: 'The pitch is written from the integration, and only from it.',
    );

    // Now the client changes their mind, which is the commonest thing that
    // happens on this screen.
    await tester.tap(find.text(session.directions.first.title));
    await tester.pump();

    expect(
      library.open!.integration,
      isNull,
      reason:
          'An integration computed for a set nobody has any more describes a '
          'selection that no longer exists, and it reads as current.',
    );
    expect(
      library.open!.pitch,
      isEmpty,
      reason: 'A launch document made from it is stale for the same reason.',
    );
  });

  testWidgets('a phone reaches the integrator by hand', (
    WidgetTester tester,
  ) async {
    final (Library library, Sitting sitting, Session session) = await assembled(
      tester,
      canDrive: false,
    );

    await tester.tap(find.text(session.directions.first.title));
    await tester.pump();

    unawaited(
      sitting.integrate(
        library.open!,
        library.open!.selection,
        library.settings,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Copy this turn'),
      findsOneWidget,
      reason:
          'Without this the Android client stops one step short of the thing '
          'it exists to produce: the interview, the sitting and the dossier '
          'all work, and the pitch is unreachable.',
    );
    sitting.stop();
    await tester.pump();
  });
}
