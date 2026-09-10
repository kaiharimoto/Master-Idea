import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/app.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:mi_core/mi_core.dart';

import 'offline_updater.dart';

Widget app(Library library) =>
    MasterIdeaApp(library: library, updater: offlineUpdater());

void main() {
  // Widget tests must not touch the filesystem: real writes cannot complete
  // in the tester's fake-async zone, so a test that persists either hangs or
  // races depending on machine load.
  Library fresh() => Library(inMemory: true);

  testWidgets('the tool moves first, with no blank canvas anywhere', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fresh()));
    await tester.pump();

    expect(find.text('What is the idea?'), findsOneWidget,
        reason:
            'Arriving at an empty document waiting to be filled puts the work '
            'back on someone who came here because they do not know what to '
            'do with their idea.');
    expect(find.byType(TextField), findsOneWidget,
        reason: 'One question, one field. Not a workspace.');
  });

  testWidgets('an idea opens the proceeding at the next question', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fresh()));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'An essay about why unattended work has to be auditable.',
    );
    await tester.tap(find.text('Convene'));
    await tester.pumpAndSettle();

    // The step mark is set in the archive's small caps, which is what the
    // eyebrow style does to every label in this app.
    expect(find.textContaining('QUESTION 2 OF'), findsOneWidget);
    expect(find.textContaining('What form does this take'), findsOneWidget,
        reason:
            'The medium is asked second because it selects the domain '
            'profile, which changes what counts as a good direction.');
  });

  testWidgets('choosing a medium composes the rest of the interview', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(app(fresh()));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'A song about leaving.');
    await tester.tap(find.text('Convene'));
    await tester.pumpAndSettle();

    // The profiles are offered by name, and each says what a good direction
    // looks like in that medium.
    expect(find.text('Song or composition'), findsOneWidget);
    await tester.ensureVisible(find.text('Song or composition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Song or composition'));
    await tester.pumpAndSettle();

    final int composed = InterviewComposer.compose(profileId: 'song').length;
    expect(find.textContaining('OF $composed'), findsOneWidget,
        reason:
            'The interview is composed from the bank for this medium rather '
            'than improvised, so its length is knowable the moment the medium '
            'is chosen.');
  });

  testWidgets('nothing on arrival reads as a chat', (WidgetTester tester) async {
    await tester.pumpWidget(app(fresh()));
    await tester.pump();

    expect(find.byType(ListView), findsNothing,
        reason:
            'A scrolling list of turns is the shape of a chat app, and this '
            'is a proceeding: one thing on screen, with a state and an '
            'outcome.');
  });
}
