import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_design/mi_design.dart';

/// Master Prompt's design system, when both halves happen to be checked out
/// side by side. CI checks out one repository at a time, so the test that
/// reads it skips rather than failing — a cross-repository assertion that goes
/// red on every CI run is a test nobody keeps.
File? mp(String name) {
  final File f = File(
    '../../../Master-Prompt/packages/mp_design/lib/src/$name',
  );
  return f.existsSync() ? f : null;
}

void main() {
  group('the two halves are one family', () {
    test('the palette is Master Prompt\'s, value for value', () {
      // Checked against the numbers rather than against a memory of them: the
      // point of the pair looking alike is that they *are* alike, and a token
      // nudged here would drift them apart one commit at a time.
      expect(MiColors.light.canvas, const Color(0xFFFBFBFA));
      expect(MiColors.light.ink, const Color(0xFF17181A));
      expect(MiColors.light.line, const Color(0xFFE6E5E1));
      expect(MiColors.dark.canvas, const Color(0xFF0E0F11));
      expect(MiColors.dark.ink, const Color(0xFFECEDEE));
    });

    test('the type is the same Inter at the same scale', () {
      expect(MiType.family, 'Inter');
      expect(MiType.question.fontSize, 30);
      expect(MiType.body.fontSize, 17);
      expect(MiType.eyebrow.letterSpacing, 1.2);
    });

    test('the grid is the same 8-point grid', () {
      expect(MiSpace.md, 16);
      expect(MiSpace.readingWidth, 620);
      expect(MiSpace.tapTarget, 56);
    });
  });

  group('the one thing this half adds', () {
    test('only MiVerdict paints with the reserved colour', () {
      // A rule about colour can only be kept by being a rule about code. A
      // second place that reached for oxblood would make the first one mean
      // nothing, so this reads the source and names every class that touches
      // it.
      // Every file that draws, not just the one that did when this was
      // written: charts arrived later, and a rule that only watches the file
      // it was born in stops being a rule the moment a second one appears.
      final List<String> reaching = <String>[
        for (final FileSystemEntity f in Directory('lib/src').listSync())
          if (f is File && f.path.endsWith('.dart'))
            for (final String chunk
                in f
                    .readAsStringSync()
                    .split(RegExp(r'^class ', multiLine: true))
                    .skip(1))
              if (chunk.contains('c.verdict'))
                chunk.split(RegExp(r'[ ({]')).first,
      ];
      expect(
        reaching,
        <String>['MiVerdict'],
        reason:
            'A council\'s whole output is judgement. It stops being findable '
            'the moment anything else is that colour.',
      );
    });

    test('Master Prompt has no such colour, and needs none', () {
      final File? file = mp('tokens.dart');
      if (file == null) {
        markTestSkipped('Master Prompt is not checked out beside this one.');
        return;
      }
      final String theirs = file.readAsStringSync();
      expect(
        theirs.contains('verdict'),
        isFalse,
        reason:
            'The addition belongs to the half that produces verdicts. If it '
            'ever appears there too, these two files have started being '
            'edited as one and the family resemblance is now a coincidence.',
      );
    });

    test('the Material theme is never handed it', () {
      for (final MiColors c in <MiColors>[MiColors.light, MiColors.dark]) {
        final ThemeData t = buildMiTheme(c, dark: c == MiColors.dark);
        expect(t.colorScheme.primary, isNot(c.verdict));
        expect(
          t.colorScheme.error,
          isNot(c.verdict),
          reason: 'A failure is not a judgement and must not look like one.',
        );
      }
    });

    test('a verdict is set at reading size', () {
      expect(
        MiType.verdict.fontSize,
        MiType.body.fontSize,
        reason:
            'The colour carries it. Set larger, it would be the closest '
            'thing this design has to a chart.',
      );
    });
  });

  group('the surfaces', () {
    test('are flat, and structure comes from hairlines', () {
      final ThemeData t = buildMiTheme(MiColors.light, dark: false);
      expect(t.cardTheme.elevation, 0);
      expect(t.dividerTheme.thickness, 1);
      expect(t.splashFactory, NoSplash.splashFactory);
    });

    test('are set in the vendored font, not whatever the platform has', () {
      final ThemeData t = buildMiTheme(MiColors.light, dark: false);
      expect(
        t.textTheme.bodyMedium!.fontFamily,
        contains('mi_design'),
        reason:
            'An unqualified family resolves to nothing and falls through to '
            'the platform sans, so the same screen would be set in Roboto on '
            'Android and Segoe on Windows.',
      );
    });
  });

  testWidgets('a verdict names the seat that gave it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMiTheme(MiColors.light, dark: false),
        home: const Scaffold(
          body: MiVerdict(
            dimension: 'Mechanism',
            verdict: 'specified',
            because: 'It says what would be built first.',
            by: 'assessor#2.4',
          ),
        ),
      ),
    );
    expect(find.text('specified'), findsOneWidget);
    expect(find.text('assessor#2.4'), findsOneWidget);
    expect(find.text('MECHANISM'), findsOneWidget);
  });

  testWidgets('a collapsed disclosure does not build its child', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMiTheme(MiColors.light, dark: false),
        home: const Scaffold(
          body: MiDisclosure(
            label: 'The full ledger',
            child: Text('territory nobody has entered'),
          ),
        ),
      ),
    );
    expect(
      find.text('territory nobody has entered'),
      findsNothing,
      reason:
          'AnimatedCrossFade builds both branches, so a disclosure built '
          'with it announces its contents to a screen reader while looking '
          'closed.',
    );

    await tester.tap(find.text('The full ledger'));
    await tester.pumpAndSettle();
    expect(find.text('territory nobody has entered'), findsOneWidget);
  });

  testWidgets('a panel with an accent bar lays out inside a scroll view', (
    WidgetTester tester,
  ) async {
    // `CrossAxisAlignment.stretch` in a Row demands a bounded height, which it
    // never has inside a scroll view — the accent bar is the third layout
    // crash this shape caused in the other half.
    await tester.pumpWidget(
      MaterialApp(
        theme: buildMiTheme(MiColors.light, dark: false),
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              MiPanel(
                accent: MiColors.light.ink,
                child: const Text('something needing attention'),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('something needing attention'), findsOneWidget);
  });
}
