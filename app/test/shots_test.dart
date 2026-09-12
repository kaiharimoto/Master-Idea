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
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final Library library = Library(inMemory: true);
    await library.load();
    // Four rounds of a real shape, because an empty sitting shows only empty
    // states and this screen's whole job is what it looks like with a run
    // behind it.
    await library.save(_afterFourRounds(await library.begin(interview())));
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

/// A session as it stands four rounds in: the arc bending toward dryness,
/// clusters with weight, ground mapped, and the calls that bought it.
Session _afterFourRounds(Session base) {
  DateTime at(int m) => DateTime.utc(2026, 3, 1, 9, m);
  const List<String> angles = <String>[
    'inversion',
    'first-principles',
    'audience-shift',
    'failure-autopsy',
  ];
  const List<(String, String)> clusters = <(String, String)>[
    ('what-it-is-for', 'What the thing is for'),
    ('who-for', 'Who it is for'),
    ('how-it-survives', 'How it survives'),
    ('what-it-refuses', 'What it refuses'),
  ];
  const List<String> titles = <String>[
    'Sell the archive, keep the index',
    'Charge the reader, never the writer',
    'Refuse every commission over a week long',
    'Publish the failures beside the findings',
    'Let the council be hired, not the answer',
    'Make the dissent the product',
    'Ship the ledger before the dossier',
    'Price it by the question, not by the hour',
    'Hand over the transcript and nothing else',
    'Start from what it must never become',
  ];
  // Unevenly, the way a real search clusters: most of it lands in one or two
  // places and the rest is a tail. An even split would draw four bars of the
  // same length and say nothing.
  const List<int> weights = <int>[0, 0, 0, 0, 1, 1, 1, 2, 2, 3];
  const List<int> keptPerRound = <int>[31, 19, 7, 0];

  final List<Direction> directions = <Direction>[];
  final List<Rating> ratings = <Rating>[];
  final List<RoundRecord> rounds = <RoundRecord>[];
  final List<ModelCall> calls = <ModelCall>[];
  int n = 0;

  for (int r = 1; r <= keptPerRound.length; r++) {
    final List<String> kept = <String>[];
    for (int i = 0; i < keptPerRound[r - 1]; i++) {
      n++;
      final String id = 'd-${n.toString().padLeft(4, '0')}';
      final (String, String) cluster = clusters[weights[i % weights.length]];
      directions.add(
        Direction(
          id: id,
          clusterId: cluster.$1,
          clusterName: cluster.$2,
          ambition: Ambition.values[i % Ambition.values.length],
          title: titles[(n * 7) % titles.length],
          statement:
              'Treat the idea as though this were the only thing it '
              'had to get right.',
          mechanism:
              'Concretely, the smallest version of it ships first and '
              'everything else follows from what that teaches.',
          proposedBy: 'prospector#$r.${i + 1}',
          round: r,
          angleId: angles[i % angles.length],
          trace: const TraceLink(
            answerModuleId: 'raw-idea',
            quote: 'the idea as the client first said it',
          ),
        ),
      );
      kept.add(id);
      for (final RatingDimension d in ratingDimensions) {
        ratings.add(
          Rating(
            directionId: id,
            dimensionId: d.id,
            verdict: d.vocabulary.rungs[d.vocabulary.rungs.length ~/ 2],
            vocabularyId: d.vocabulary.id,
            ratedBy: 'assessor#$r.${i + 1}',
            context: RatingContext.forDirection(
              directions.last,
              d,
              briefRestatement: base.interview.brief.restatement,
            ),
            because: 'Judged on what is written, not on who wrote it.',
          ),
        );
      }
    }
    for (int c = 0; c < 40 + keptPerRound[r - 1] * 13; c++) {
      calls.add(
        ModelCall(
          at: at((r - 1) * 45 + 1),
          purpose: 'propose',
          by: 'prospector#$r.1',
          promptChars: 9000,
          replyChars: 2400,
          tokensIn: 4,
          tokensOut: 600,
          cacheCreationTokens: 1800,
          cacheReadTokens: 400,
        ),
      );
    }
    rounds.add(
      RoundRecord(
        number: r,
        angleSet: angles,
        returns: <AngleReturn>[
          for (int a = 0; a < angles.length; a++)
            AngleReturn(
              angleId: angles[a],
              by: 'prospector#$r.${a + 1}',
              proposedIds: List<String>.filled(12, 'p'),
              keptIds: kept,
              exhausted: r == 4,
            ),
        ],
        rejections: <DedupRejection>[
          for (int d = 0; d < 48 - keptPerRound[r - 1]; d++)
            const DedupRejection(
              candidateTitle: 'The same idea from another side',
              candidateSubstance: 'substance',
              againstDirectionId: 'd-0001',
              ruleId: 'jaccard-substance-v1@0.62',
              similarity: 0.81,
            ),
        ],
        refusals: const <Refusal>[
          Refusal(
            candidateTitle: 'A direction with nowhere to come from',
            reason: 'Traced to neither an interview answer nor a named gap.',
            kind: 'unsourced',
          ),
        ],
        newDirectionIds: kept,
        gapsNamed: r == 1
            ? const <String>['t-1', 't-2', 't-3']
            : const <String>[],
        startedAt: at((r - 1) * 45),
        endedAt: at(r * 45 - 5),
      ),
    );
  }

  return base.copyWith(
    directions: directions,
    ratings: ratings,
    rounds: rounds,
    ledger: CoverageLedger(
      territories: <Territory>[
        for (int i = 0; i < 7; i++)
          Territory(
            id: 'e-$i',
            name: 'Ground the council entered',
            description: 'Walked in round one.',
            status: TerritoryStatus.explored,
            firstWrittenInRound: 0,
          ),
        for (int i = 0; i < 4; i++)
          Territory(
            id: 'l-$i',
            name: 'Ground deliberately left',
            description: 'Put out of bounds in the interview.',
            status: TerritoryStatus.dropped,
            firstWrittenInRound: 0,
            reason: 'The client ruled it out.',
          ),
        for (int i = 0; i < 6; i++)
          Territory(
            id: 'o-$i',
            name: 'Ground nobody has reached',
            description: 'Still open.',
            status: TerritoryStatus.gap,
            firstWrittenInRound: 0,
          ),
      ],
    ),
    manifest: RunManifest(
      sessionId: base.manifest.sessionId,
      templateId: base.manifest.templateId,
      tier: base.manifest.tier,
      transport: 'cli',
      startedAt: at(0),
      calls: calls,
    ),
  );
}
