import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_design/mi_design.dart';

/// The charts, at the shapes real data actually arrives in.
///
/// A chart that overflows is a chart nobody sees, and every one of these is
/// drawn beside others in a scrolling column where an overflow is a red band
/// across the thing it was meant to explain.
void main() {
  Future<void> draw(WidgetTester tester, Widget child, {double width = 360}) =>
      tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MiTheme(
            colors: MiColors.light,
            isDark: false,
            child: Center(
              child: SizedBox(width: width, child: child),
            ),
          ),
        ),
      );

  group('columns', () {
    testWidgets('a round that kept nothing still draws', (
      WidgetTester tester,
    ) async {
      await draw(
        tester,
        const MiColumns(data: <MiColumn>[MiColumn('1', 60), MiColumn('2', 0)]),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text('0'),
        findsOneWidget,
        reason:
            'A round keeping nothing is what ends a sitting, so an absent '
            'mark would hide the one thing the sequence exists to show.',
      );
    });

    testWidgets('every value being zero does not divide by it', (
      WidgetTester tester,
    ) async {
      await draw(
        tester,
        const MiColumns(data: <MiColumn>[MiColumn('1', 0), MiColumn('2', 0)]),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long run of rounds fits the width it is given', (
      WidgetTester tester,
    ) async {
      await draw(
        tester,
        MiColumns(
          data: <MiColumn>[for (int i = 1; i <= 20; i++) MiColumn('$i', i * 3)],
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('bars', () {
    testWidgets('a label too long for its column is cut, not overflowed', (
      WidgetTester tester,
    ) async {
      await draw(
        tester,
        const MiBars(
          data: <MiBar>[
            MiBar('A cluster whose name nobody thought to keep short', 31),
            MiBar('Short', 2),
          ],
        ),
        width: 280,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('31'), findsOneWidget);
    });
  });

  group('the split bar', () {
    testWidgets('says so rather than drawing nothing when nothing is mapped', (
      WidgetTester tester,
    ) async {
      await draw(tester, const MiSplitBar(parts: <MiSplit>[]));
      expect(find.textContaining('nothing mapped yet'), findsOneWidget);
    });

    testWidgets('writes out every share it draws', (WidgetTester tester) async {
      await draw(
        tester,
        const MiSplitBar(
          parts: <MiSplit>[
            MiSplit('entered', 7),
            MiSplit('left aside', 4),
            MiSplit('still open', 6),
          ],
        ),
      );

      expect(
        find.textContaining('7 entered · 4 left aside · 6 still open'),
        findsOneWidget,
        reason:
            'Nothing in this palette can tell three shares apart by colour '
            'alone, and it should not have to: the bar is a picture of '
            'something the reader can also read.',
      );
    });
  });

  group('the fan-in', () {
    testWidgets('an angle with nothing left does not look like one still out', (
      WidgetTester tester,
    ) async {
      await draw(
        tester,
        const MiFanIn(total: 12, back: 7, exhausted: 1, note: '7 of 12 back'),
      );

      expect(tester.takeException(), isNull);
      final Semantics s = tester.widget(find.byType(Semantics).first);
      expect(
        s.properties.label,
        contains('nothing left'),
        reason:
            'Came back empty and still searching are the two states a dryness '
            'decision turns on, and a screen reader gets no shapes at all.',
      );
    });

    testWidgets('more back than seated does not paint outside the row', (
      WidgetTester tester,
    ) async {
      await draw(tester, const MiFanIn(total: 4, back: 9, exhausted: 7));
      expect(tester.takeException(), isNull);
    });
  });
}
