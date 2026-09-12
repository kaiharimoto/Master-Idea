import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/widgets/document_view.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

Widget wrap(MiDocument doc) => MaterialApp(
  theme: buildMiTheme(MiColors.light, dark: false),
  home: Scaffold(body: DocumentView(doc)),
);

void main() {
  testWidgets('a verdict reaches the one widget allowed to paint oxblood', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MiDocument(<DocBlock>[
          DocBlock(
            BlockKind.verdict,
            'specified — it says what would be built first (assessor#2.4, '
            'drawing on presence)',
            label: 'Mechanism',
          ),
        ]),
      ),
    );

    final MiVerdict rendered = tester.widget<MiVerdict>(find.byType(MiVerdict));
    expect(rendered.verdict, 'specified');
    expect(rendered.by, contains('assessor#2.4'));
    expect(rendered.dissenting, isFalse);
  });

  testWidgets('a dissent is set as a dissent, not as a second verdict', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MiDocument(<DocBlock>[
          DocBlock(
            BlockKind.dissent,
            'gestured — the mechanism is read more generously than it '
            'deserves (dissenter#2.1)',
            label: 'Dissent',
          ),
        ]),
      ),
    );
    expect(
      tester.widget<MiVerdict>(find.byType(MiVerdict)).dissenting,
      isTrue,
      reason:
          'Dissent held rather than averaged away is the point of recording '
          'it at all, so it has to be visibly a minority verdict.',
    );
  });

  testWidgets('no numeral appears in a rendered verdict', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MiDocument(<DocBlock>[
          DocBlock(
            BlockKind.verdict,
            'commanding — because',
            label: 'Ambition',
          ),
        ]),
      ),
    );
    final MiVerdict v = tester.widget<MiVerdict>(find.byType(MiVerdict));
    expect(
      RegExp(r'[0-9]').hasMatch(v.verdict),
      isFalse,
      reason:
          'A number invites averaging, and averaging is how dissent '
          'disappears.',
    );
  });

  testWidgets('a marked assumption is set apart without borrowing the accent', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const MiDocument(<DocBlock>[
          DocBlock(
            BlockKind.revisit,
            'The client would rather wait than be asked again.',
            label: 'Revisit',
          ),
        ]),
      ),
    );
    expect(
      find.byType(MiVerdict),
      findsNothing,
      reason: 'An assumption is not a judgement.',
    );
    expect(find.textContaining('rather wait'), findsOneWidget);
  });
}
