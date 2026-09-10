import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../widgets/document_actions.dart';
import '../widgets/document_view.dart';

/// The coverage ledger: the map of the idea space, as the cartographer drew it.
///
/// Rendered from the stored session and nothing else, so it opens with no
/// council, no key and no network — a month later, on a machine that has never
/// run a sitting.
class LedgerScreen extends StatelessWidget {
  const LedgerScreen({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    if (session.ledger.territories.isEmpty) {
      return const MiEmpty(
        title: 'Nothing has been mapped yet',
        detail:
            'The cartographer draws the map at each barrier, so it fills as '
            'the sitting runs. Its edges are the point: what was entered, what '
            'was deliberately left, and what is still open.',
      );
    }
    final MiDocument document = LedgerRenderer.render(session);

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
                filename: '${session.taskId}-ledger.txt',
                text: document.toText(),
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
