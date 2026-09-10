import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../widgets/document_actions.dart';
import '../widgets/document_view.dart';

/// The case file handed back to the client.
///
/// Every direction with its independent rating, the reasoning, the dissent
/// shown rather than averaged away, the link back to what it came from, and
/// every assumption the sitting made marked as a revisit point. It is the one
/// place all of that is visible at once — or visibly absent, which is the
/// point of putting it in one frame.
class DossierScreen extends StatelessWidget {
  const DossierScreen({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    if (session.directions.isEmpty) {
      return const MiEmpty(
        title: 'The case file is empty',
        detail:
            'Nothing is written here that a seat did not say, so it fills as '
            'the council proposes and rates rather than at the end.',
      );
    }
    final MiDocument document = DossierRenderer.render(session);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MiSpace.conversationWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                MiSpace.lg,
                MiSpace.md,
                MiSpace.lg,
                0,
              ),
              child: DocumentActions(
                filename: '${session.taskId}-dossier.txt',
                text: document.toText(),
                trailing: _Audit(session: session),
              ),
            ),
            const MiRule(),
            Expanded(child: DocumentView(document)),
          ],
        ),
      ),
    );
  }
}

/// The invariant suite, run against the stored session and shown here.
///
/// The command line has had `mi check` since before either client existed;
/// the app, whose whole claim is that the completeness of a sitting is
/// auditable rather than asserted, had no way to run it. On a phone — where
/// the session was carried by hand and is most in need of checking — there
/// was none at all.
class _Audit extends StatefulWidget {
  const _Audit({required this.session});

  final Session session;

  @override
  State<_Audit> createState() => _AuditState();
}

class _AuditState extends State<_Audit> {
  InvariantReport? _report;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final InvariantReport? report = _report;

    if (report == null) {
      return MiButton(
        label: 'Check the invariants',
        onPressed: () =>
            setState(() => _report = InvariantSuite.run(widget.session)),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        MiTag(
          report.holds ? 'all three hold' : '${report.findings.length} failing',
          tone: report.holds ? c.success : c.danger,
        ),
        const SizedBox(width: MiSpace.sm),
        MiInfo(
          title: 'What was checked',
          body: report.holds
              ? 'Traceability, independent rating and run-until-dry, over the '
                    'stored session alone — no council, no network. Every '
                    'direction traces to something the client said or a gap '
                    'named in an earlier round, no seat rated what it '
                    'proposed, and the run ended on two consecutive rounds '
                    'that returned nothing new.'
              : report.summary,
        ),
      ],
    );
  }
}
