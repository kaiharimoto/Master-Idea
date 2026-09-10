import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../widgets/document_actions.dart';

/// The export: a launch document built from what the client selected.
///
/// It carries the directions they chose and the integration computed across
/// that set, and it is plain prose — no tag, no tool syntax, no system-prompt
/// idiom — because the receiving end may be any model. The one machine-readable
/// part is a small line-oriented block at the end, which is what lets Master
/// Prompt open a mission from this without anything being retyped.
class PitchScreen extends StatelessWidget {
  const PitchScreen({required this.library, required this.session, super.key});

  final Library library;
  final Session session;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Session s = library.open ?? session;
    final String pitch = s.pitch;

    if (pitch.isEmpty) {
      return const MiEmpty(
        title: 'There is no pitch yet',
        detail:
            'Select directions in Assembly and have the council compute what '
            'they become together. The pitch is made of that, and of nothing '
            'the client did not choose.',
      );
    }

    final List<String> tells = PitchPortability.tells(pitch);

    return SingleChildScrollView(
      child: MiLeaf(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const MiEyebrow('Pitch prompt'),
            const SizedBox(height: MiSpace.sm),
            // A row rather than a Row: at a large text scale the button and
            // the note beside it overflowed the line they shared.
            DocumentActions(filename: '${s.taskId}-pitch.md', text: pitch),
            Text(
              tells.isEmpty
                  ? 'Portable: nothing in it ties it to one provider.'
                  : 'Not portable — found ${tells.join(', ')}.',
              style: MiType.caption.copyWith(
                color: tells.isEmpty ? c.inkMuted : c.warning,
              ),
            ),
            const SizedBox(height: MiSpace.lg),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            // Shown verbatim, in the same measure it will be read in. What is
            // on screen is exactly what leaves — a preview that re-rendered
            // the selection would be a second implementation free to drift
            // from the file itself.
            SelectableText(pitch, style: MiType.prose.copyWith(color: c.ink)),
            const SizedBox(height: MiSpace.xxl),
          ],
        ),
      ),
    );
  }
}
