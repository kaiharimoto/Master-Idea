import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/app.dart';
import 'package:master_idea/src/screens/home.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import 'library_test.dart' show interview;
import 'offline_updater.dart';

/// The wide branch of the shell.
///
/// Widget tests default to 800×600, which is below the 900px gate — so every
/// other test in this suite exercises the narrow layout, and the branch a
/// desktop actually runs would go uncovered. That is exactly how a fresh
/// desktop install turns out to have no way of reaching Settings.
void main() {
  Future<void> wide(WidgetTester tester, Library library) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pump();
  }

  testWidgets('a wide window shows the rail and every region on it', (
    WidgetTester tester,
  ) async {
    final Library library = Library(inMemory: true);
    await library.load();
    await library.begin(interview());

    await wide(tester, library);

    for (final Region r in Region.values) {
      expect(find.text(r.title), findsWidgets,
          reason:
              '${r.title} has no way in on a wide window, which is how a '
              'desktop install ends up with a region nobody can reach.');
    }
  });

  testWidgets('choosing a region opens it beside the rail, not over it', (
    WidgetTester tester,
  ) async {
    final Library library = Library(inMemory: true);
    await library.load();
    final Session s = await library.begin(interview());

    await wide(tester, library);
    await tester.tap(find.text(Region.settings.title));
    await tester.pumpAndSettle();

    expect(find.text(s.title), findsWidgets,
        reason:
            'A pushed route covers the rail too, which turns a 1600px window '
            'into a phone page and takes the session with it.');
    expect(find.text('Appearance'), findsOneWidget);
  });

  testWidgets('the narrow layout is the one below the gate', (
    WidgetTester tester,
  ) async {
    final Library library = Library(inMemory: true);
    await library.load();
    await library.begin(interview());

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pump();

    expect(find.byIcon(Icons.menu), findsOneWidget,
        reason:
            'With one column the regions live behind a menu; the rail would '
            'leave no room for the region itself.');
  });

  test('the gate is a layout question, not a platform one', () {
    // Named here because confusing the two is how a narrow window on a desktop
    // gets the phone experience and a tablet gets a button it cannot use.
    expect(MiSpace.wideGate, 900);
  });
}
