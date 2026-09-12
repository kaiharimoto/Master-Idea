import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/screens/dossier.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:master_idea/src/store/sitting.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import 'library_test.dart' show interview;
import 'support/scripted_council.dart';

/// The case file, and the check that it is what it claims to be.
void main() {
  testWidgets('the dossier can leave the app, and can be audited in it', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final Library library = Library(inMemory: true);
    await library.load();
    final Session opened = await library.begin(interview());
    await Sitting(
      library,
      canDrive: true,
      open: (_, _) async => ScriptedCouncil(),
    ).begin(opened, library.settings);

    await tester.pumpWidget(
      MaterialApp(
        home: MiTheme(
          colors: MiColors.light,
          isDark: false,
          child: Scaffold(body: DossierScreen(session: library.open!)),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Copy'),
      findsOneWidget,
      reason:
          'A council\'s case file is a document people forward and keep. It '
          'could not leave the application at all.',
    );
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('Check the invariants'));
    await tester.pump();
    expect(
      find.text('ALL THREE HOLD'),
      findsOneWidget,
      reason:
          'The command line has had this check since before either client '
          'existed. On a phone, where the session was carried by hand and is '
          'most in need of checking, there was no way to run it.',
    );
  });
}
