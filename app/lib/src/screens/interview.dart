import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/naming.dart';

/// The interview as it closed: frozen, and readable forever.
///
/// Nothing here is editable. The gate closed once, and no answer may be
/// re-elicited afterwards — not because asking again would be unhelpful, but
/// because the sitting is unattended by design, and a tool that can ask again
/// will, at hour three, of a room with nobody in it.
class InterviewScreen extends StatelessWidget {
  const InterviewScreen({
    required this.library,
    required this.session,
    required this.onBegun,
    super.key,
  });

  final Library library;
  final Session session;
  final VoidCallback onBegun;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final InterviewRecord r = session.interview;

    return SingleChildScrollView(
      child: MiLeaf(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const MiEyebrow('The interview, as it closed'),
            const SizedBox(height: MiSpace.md),
            Text(
              'The brief, approved verbatim',
              style: MiType.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: MiSpace.sm),
            Text(
              r.brief.restatement,
              style: MiType.prose.copyWith(color: c.ink),
            ),
            const SizedBox(height: MiSpace.sm),
            Text(
              'Approved ${r.brief.approvedAt.toIso8601String()} · '
              '${r.brief.hash}',
              style: MiType.mono.copyWith(color: c.inkFaint),
            ),
            const SizedBox(height: MiSpace.xl),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            Text(
              'Declared unknowns',
              style: MiType.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: MiSpace.xs),
            Text(
              'The sitting\'s licence to proceed without you.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MiSpace.sm),
            for (final DeclaredUnknown u in r.unknowns)
              MiRecord(label: u.question, value: u.licence),
            const SizedBox(height: MiSpace.xl),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            Text('The sitting', style: MiType.title.copyWith(color: c.ink)),
            const SizedBox(height: MiSpace.xs),
            MiRecord(label: tierName(r.verdict), value: r.verdict.reasoning),
            MiRecord(
              label: 'Expected',
              value: tierExpectation(r.verdict),
              style: MiType.caption,
            ),
            const SizedBox(height: MiSpace.xl),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            Text(
              'Everything you said, as you said it',
              style: MiType.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: MiSpace.xs),
            Text(
              'Stored verbatim, because every direction in the dossier traces '
              'back to one of these. A paraphrase here would make each link '
              'point at the tool\'s own words.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MiSpace.md),
            for (final InterviewAnswer a in r.answers) ...<Widget>[
              MiRecord(
                label: moduleByIdOrNull(a.moduleId)?.name ?? a.moduleId,
                value: a.text,
              ),
              const SizedBox(height: MiSpace.xs),
              MiRule(),
            ],
            const SizedBox(height: MiSpace.xl),
            if (session.rounds.isEmpty)
              MiButton(
                label: 'Go to the sitting',
                onPressed: onBegun,
                kind: MiButtonKind.primary,
              ),
            const SizedBox(height: MiSpace.xxl),
          ],
        ),
      ),
    );
  }
}
