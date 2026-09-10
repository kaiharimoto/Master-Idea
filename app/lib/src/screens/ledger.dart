import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

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
    final MiColors c = MiTheme.colorsOf(context);
    if (session.ledger.territories.isEmpty) {
      return _nothingYet(
        c,
        'The map is drawn at each barrier, so it fills as the sitting runs '
        'rather than at the end. Nothing has been mapped yet.',
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MiSpace.documentWidth),
        child: DocumentView(LedgerRenderer.render(session)),
      ),
    );
  }
}

Widget _nothingYet(MiColors c, String what) => Center(
  child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: MiSpace.readingWidth),
    child: Padding(
      padding: const EdgeInsets.all(MiSpace.xl),
      child: Text(
        what,
        style: MiType.prose.copyWith(color: c.inkMuted),
        textAlign: TextAlign.center,
      ),
    ),
  ),
);
