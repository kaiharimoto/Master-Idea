import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/sitting.dart';
import '../widgets/carry_panel.dart';

/// Where the client presides.
///
/// They select directions from the dossier and see what the chosen set becomes
/// **together** — integration computed across the whole selection, not written
/// into individual directions. That is the entire reason this is a stage of
/// its own: forty directions each carrying their own integration story is
/// forty stories, and the client still has to work out what their five choices
/// add up to.
///
/// The council never decides what ships. Nothing reaches the pitch that is not
/// selected here.
class AssemblyScreen extends StatefulWidget {
  const AssemblyScreen({
    required this.library,
    required this.sitting,
    required this.session,
    super.key,
  });

  final Library library;
  final Sitting sitting;
  final Session session;

  @override
  State<AssemblyScreen> createState() => _AssemblyScreenState();
}

class _AssemblyScreenState extends State<AssemblyScreen> {
  String? _problem;

  Session get _session => widget.library.open ?? widget.session;

  Future<void> _toggle(String id) async {
    final Session s = _session;
    final List<String> next = <String>[...s.selection];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    // The integration was computed for a set the client no longer has, so it
    // goes — and the pitch made from it goes with it. A launch document
    // describing directions somebody has since dropped is worse than none,
    // because it reads as current.
    final bool stale = s.integration != null && s.integration!.isStaleFor(next);
    try {
      await widget.library.save(
        s.copyWith(selection: next, dropIntegration: stale, dropPitch: stale),
      );
      setState(() => _problem = null);
    } on Object catch (e) {
      setState(() => _problem = 'That selection could not be stored. $e');
    }
  }

  Future<void> _integrate() async {
    final Session s = _session;
    if (s.selection.isEmpty) return;
    setState(() => _problem = null);

    final Integration? integration = await widget.sitting.integrate(
      s,
      s.selection,
      widget.library.settings,
    );
    if (!mounted) return;
    if (integration == null) {
      setState(
        () => _problem =
            widget.sitting.problem ??
            'The integrator returned nothing readable.',
      );
      return;
    }
    // Read again: the client may have changed the selection while the council
    // was working, and an integration for a set nobody has is the thing this
    // screen exists to refuse.
    final Session now = _session;
    if (integration.isStaleFor(now.selection)) {
      setState(
        () => _problem =
            'The selection changed while the council was working, so what '
            'came back describes a set you no longer have. Compute it again.',
      );
      return;
    }
    final Session assembled = now.copyWith(integration: integration);
    await widget.library.save(
      assembled.copyWith(pitch: PitchComposer.compose(assembled)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.library,
        widget.sitting,
      ]),
      builder: (BuildContext context, _) {
        final Session s = _session;
        final Integration? integration = s.integration;
        final CouncilTurn? carrying = widget.sitting.hand?.waiting;
        final bool computing = widget.sitting.isBusy;

        if (s.directions.isEmpty) {
          return const MiEmpty(
            title: 'There is nothing to preside over yet',
            detail:
                'The council proposes and rates; you decide what ships. Open '
                'the sitting and this fills as directions arrive.',
          );
        }

        return SingleChildScrollView(
          child: MiLeaf(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MiEyebrow('Assembly'),
                const SizedBox(height: MiSpace.md),
                Text(
                  'Which of these are yours?',
                  style: MiType.question.copyWith(color: c.ink),
                ),
                const SizedBox(height: MiSpace.sm),
                Text(
                  'The council rated them; it does not decide what ships. Only '
                  'what you select here reaches the pitch.',
                  style: MiType.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: MiSpace.lg),
                for (final MapEntry<String, List<Direction>> cluster
                    in s.clusters.entries) ...<Widget>[
                  MiEyebrow(cluster.value.first.clusterName),
                  const SizedBox(height: MiSpace.xs),
                  for (final Direction d in cluster.value)
                    _row(c, d, s.selection.contains(d.id)),
                  const SizedBox(height: MiSpace.md),
                ],
                const SizedBox(height: MiSpace.lg),
                const MiRule(strong: true),
                const SizedBox(height: MiSpace.lg),
                Text(
                  'What the set becomes',
                  style: MiType.title.copyWith(color: c.ink),
                ),
                const SizedBox(height: MiSpace.sm),
                if (integration == null)
                  Text(
                    s.selection.isEmpty
                        ? 'Select at least one direction. Integration is '
                              'computed across the whole selection, so there '
                              'is nothing to compute across yet.'
                        : 'What these become together has not been worked out '
                              'yet — only the council can do that, and it is '
                              'the part worth waiting for.',
                    style: MiType.prose.copyWith(color: c.inkMuted),
                  )
                else ...<Widget>[
                  Text(
                    integration.becomes,
                    style: MiType.prose.copyWith(color: c.ink),
                  ),
                  const SizedBox(height: MiSpace.md),
                  for (final Interaction i in integration.reinforcements)
                    MiRecord(
                      label: 'Reinforces',
                      value:
                          '${_title(s, i.a)} and ${_title(s, i.b)} — '
                          '${i.because}',
                      style: MiType.caption,
                    ),
                  for (final Interaction i in integration.conflicts)
                    MiRecord(
                      label: 'Conflicts',
                      value:
                          '${_title(s, i.a)} and ${_title(s, i.b)} — '
                          '${i.because}',
                      style: MiType.caption,
                    ),
                ],
                const SizedBox(height: MiSpace.lg),

                // The phone reaches the integrator the same way it reaches
                // every other seat: by hand. Without this the Android client
                // stops one step short of the thing it exists to produce.
                if (carrying != null) ...<Widget>[
                  CarryPanel(hand: widget.sitting.hand!, turn: carrying),
                  const SizedBox(height: MiSpace.lg),
                ],

                if (_problem != null) ...<Widget>[
                  MiPanel(
                    accent: c.danger,
                    child: Text(
                      _problem!,
                      style: MiType.prose.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],
                MiButton(
                  label: integration == null
                      ? 'Compute what they become'
                      : 'Compute it again',
                  kind: MiButtonKind.primary,
                  busy: computing,
                  onPressed: s.selection.isEmpty || computing
                      ? null
                      : _integrate,
                ),
                if (!widget.sitting.canDrive) ...<Widget>[
                  const SizedBox(height: MiSpace.sm),
                  Text(
                    'On a phone this is one more turn carried by hand — the '
                    'last one, and the one that writes the pitch.',
                    style: MiType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
                const SizedBox(height: MiSpace.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  String _title(Session s, String id) => s.directionById(id)?.title ?? id;

  Widget _row(MiColors c, Direction d, bool selected) => Semantics(
    button: true,
    selected: selected,
    label: d.title,
    child: InkWell(
      onTap: () => _toggle(d.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // A mark rather than a glyph in a fixed box: the box clipped at
            // large text scales, and weight alone said nothing to a screen
            // reader or to anyone who could not see it.
            Padding(
              padding: const EdgeInsets.only(right: MiSpace.sm, top: 2),
              child: Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 18,
                color: selected ? c.ink : c.inkFaint,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    d.title,
                    style: MiType.body.copyWith(
                      color: c.ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  Text(
                    '${d.ambition.name} · ${d.statement}',
                    style: MiType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
