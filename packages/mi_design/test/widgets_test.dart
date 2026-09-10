import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_design/mi_design.dart';

/// What the client actually reads off these widgets.
///
/// A rendering defect in a shared widget reaches every screen at once and
/// fails no assertion anywhere: the busy label below printed the string
/// `$label…` on the two most important buttons in the application for as long
/// as the button existed, because an escape in an interpolation is invisible
/// in review and invisible in a test that only taps things.
void main() {
  Widget framed(Widget child) => MaterialApp(
    home: MiTheme(
      colors: MiColors.light,
      isDark: false,
      child: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('a busy button says what it is busy doing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      framed(const MiButton(label: 'Compute what they become', busy: true)),
    );

    expect(find.text('Compute what they become…'), findsOneWidget);
    expect(
      find.textContaining(r'$label'),
      findsNothing,
      reason:
          'The label is interpolated, not printed. This read as debug output '
          'on every long action in the app.',
    );
  });

  testWidgets('a confirmation says what will happen, and can be refused', (
    WidgetTester tester,
  ) async {
    bool? answer;
    await tester.pumpWidget(
      framed(
        Builder(
          builder: (BuildContext context) => MiButton(
            label: 'Delete',
            onPressed: () async {
              answer = await showMiConfirm(
                context,
                title: 'Delete this session?',
                body: 'This removes the files. Nothing else has a copy.',
                action: 'Delete it',
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text('This removes the files. Nothing else has a copy.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Leave it'));
    await tester.pumpAndSettle();
    expect(
      answer,
      isFalse,
      reason: 'Refusing is the default answer, and it must be the easy one.',
    );
  });

  testWidgets('a notice appears when something silent happens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      framed(
        Builder(
          builder: (BuildContext context) => MiButton(
            label: 'Copy',
            onPressed: () => miNotice(context, 'Copied'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);
  });
}
