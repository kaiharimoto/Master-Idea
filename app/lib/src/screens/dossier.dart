import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

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
    final MiColors c = MiTheme.colorsOf(context);
    if (session.directions.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MiSpace.readingWidth),
          child: Padding(
            padding: const EdgeInsets.all(MiSpace.xl),
            child: Text(
              'The case file is empty until the council has proposed and rated '
              'something. Nothing is written here that a seat did not say.',
              style: MiType.prose.copyWith(color: c.inkMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MiSpace.documentWidth),
        child: DocumentView(DossierRenderer.render(session)),
      ),
    );
  }
}
