@Tags(<String>['shots'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/app.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:mi_core/mi_core.dart';

import 'library_test.dart' show interview;
import 'offline_updater.dart';

/// Real screenshots of the real screens.
///
/// Not a golden comparison — nothing here fails on a pixel. These are written
/// so the screens can be *looked at*, which is the only way to judge whether a
/// design reads, and the fonts are loaded because a shot set in Ahem boxes
/// tells you nothing about type.
Future<void> loadFonts() async {
  for (final String face in <String>[
    'Inter-Regular',
    'Inter-Medium',
    'Inter-SemiBold',
    'Inter-Bold',
  ]) {
    final File f = File('../packages/mi_design/assets/fonts/$face.ttf');
    final FontLoader loader = FontLoader(
      'packages/mi_design/Inter',
    )..addFont(Future<ByteData>.value(f.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }
}

void main() {
  setUpAll(loadFonts);

  Future<void> shot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
  }

  testWidgets('arrival', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Library library = Library(inMemory: true);
    await library.load();
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pumpAndSettle();
    await shot(tester, 'arrival');
  });

  testWidgets('interview', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Library library = Library(inMemory: true);
    await library.load();
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'A tool that argues with itself about an idea until it has nothing left '
      'to say.',
    );
    await tester.tap(find.text('Convene'));
    await tester.pumpAndSettle();
    await shot(tester, 'interview');
  });

  testWidgets('sitting', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Library library = Library(inMemory: true);
    await library.load();
    await library.begin(interview());
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sitting').last);
    await tester.pumpAndSettle();
    await shot(tester, 'sitting');
  });

  testWidgets('interview record', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Library library = Library(inMemory: true);
    await library.load();
    await library.begin(interview());
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pumpAndSettle();
    await shot(tester, 'record');
  });

  testWidgets('dossier', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Library library = Library(inMemory: true);
    await library.load();
    final Session s = await library.begin(interview());
    await library.save(_withDirections(s));
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dossier').last);
    await tester.pumpAndSettle();
    await shot(tester, 'dossier');
  });
}

/// One rated direction, with a dissent, so the dossier has something to set.
Session _withDirections(Session s) {
  const Direction d = Direction(
    id: 'd-0001',
    clusterId: 'what-it-is-for',
    clusterName: 'What the thing is for',
    ambition: Ambition.reckless,
    title: 'Give the archive away and charge for the index',
    statement:
        'Publish every case file and sell only the index that makes one '
        'findable.',
    mechanism:
        'The archive is static and mirrored; the index is regenerated per '
        'client against their own question.',
    proposedBy: 'prospector#1.1',
    round: 1,
    angleId: 'inversion',
    trace: TraceLink(
      answerModuleId: 'ceiling',
      quote: 'as far as it could possibly go',
    ),
  );
  final RatingContext ctx = RatingContext.forDirection(
    d,
    dimensionById('mechanism'),
    briefRestatement: s.interview.brief.restatement,
  );
  return s.copyWith(
    directions: <Direction>[d],
    ratings: <Rating>[
      Rating(
        directionId: 'd-0001',
        dimensionId: 'mechanism',
        verdict: 'specified',
        vocabularyId: 'presence',
        ratedBy: 'assessor#1.3',
        context: ctx,
        because: 'It says what would be built first and what it costs.',
        dissents: const <Dissent>[
          Dissent(
            by: 'dissenter#1.1',
            verdict: 'gestured',
            because:
                'The index is the hard half and it is described in a line.',
          ),
        ],
      ),
      Rating(
        directionId: 'd-0001',
        dimensionId: 'ambition',
        verdict: 'commanding',
        vocabularyId: 'strength',
        ratedBy: 'assessor#1.4',
        context: ctx,
        because: 'It inverts what the client assumed they were selling.',
      ),
    ],
    assumptions: const <Assumption>[
      Assumption(
        id: 'a-1',
        round: 1,
        made: 'The client would rather wait than be asked again.',
        because: 'No answer covered interruption.',
        affects: <String>['d-0001'],
        answersUnknownId: 'u-length',
      ),
    ],
  );
}
