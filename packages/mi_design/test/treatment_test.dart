import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_design/mi_design.dart';

void main() {
  group('the accent is reserved', () {
    test('only MiVerdict paints with it', () {
      // A rule about colour can only be kept by being a rule about code. The
      // palette reserves oxblood for verdicts and ratings, and a second place
      // that reaches for it makes the first one mean nothing — so this reads
      // the source and names the classes that touch `accent`.
      final String source = File('lib/src/widgets.dart').readAsStringSync();
      final List<String> chunks = source.split(RegExp(r'^class ', multiLine: true));
      final List<String> reaching = <String>[
        for (final String chunk in chunks.skip(1))
          if (chunk.contains('.accent'))
            chunk.split(RegExp(r'[ ({]')).first,
      ];
      expect(reaching, <String>['MiVerdict'],
          reason:
              'Judgement is meant to be the loudest thing on any screen. It '
              'stops being so the moment anything else is oxblood.');
    });

    test('the Material theme is never handed the accent', () {
      final ThemeData light = buildMiTheme(MiColors.light, dark: false);
      final ThemeData dark = buildMiTheme(MiColors.dark, dark: true);
      for (final (ThemeData t, MiColors c) in <(ThemeData, MiColors)>[
        (light, MiColors.light),
        (dark, MiColors.dark),
      ]) {
        expect(t.colorScheme.primary, isNot(c.accent),
            reason:
                'A stock widget reaching for `primary` would paint something '
                'verdict-coloured that is not a verdict.');
        expect(t.colorScheme.error, isNot(c.accent),
            reason:
                'A failure is not a judgement, and must not be able to look '
                'like one.');
      }
    });
  });

  group('the surfaces are flat', () {
    test('nothing in the theme is elevated', () {
      final ThemeData t = buildMiTheme(MiColors.light, dark: false);
      expect(t.cardTheme.elevation, 0);
      expect(t.dialogTheme.elevation, 0);
      expect(t.bottomSheetTheme.elevation, 0);
      expect(t.splashFactory, NoSplash.splashFactory,
          reason: 'Ink does not ripple.');
    });

    test('a field is ruled underneath, not boxed', () {
      final ThemeData t = buildMiTheme(MiColors.light, dark: false);
      expect(t.inputDecorationTheme.border, isA<UnderlineInputBorder>(),
          reason:
              'A form of boxes is the fastest way for this to start reading '
              'as a web app rather than a proceeding.');
    });
  });

  group('the type', () {
    test('is the vendored serif, not whatever the platform has', () {
      final ThemeData t = buildMiTheme(MiColors.light, dark: false);
      expect(t.textTheme.bodyMedium!.fontFamily, contains('mi_design'),
          reason:
              'An unqualified family resolves to nothing and falls through to '
              'the platform serif, so the same dossier would be set in Noto '
              'on Android and Georgia on Windows.');
    });

    test('carries no numerals of its own into a verdict', () {
      expect(MiType.verdict.fontSize, MiType.body.fontSize,
          reason:
              'The colour carries a verdict. Set larger, it would be the '
              'closest thing this design has to a chart.');
    });
  });

  testWidgets('a verdict names the seat that gave it', (WidgetTester tester) async {
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
            summary: 'The full ledger',
            child: Text('territory nobody has entered'),
          ),
        ),
      ),
    );
    expect(find.text('territory nobody has entered'), findsNothing,
        reason:
            'AnimatedCrossFade builds both branches, so a disclosure built '
            'with it announces its contents to a screen reader while looking '
            'closed.');

    await tester.tap(find.text('THE FULL LEDGER'));
    await tester.pumpAndSettle();
    expect(find.text('territory nobody has entered'), findsOneWidget);
  });
}
