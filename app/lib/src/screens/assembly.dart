import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../transport/council_session.dart';

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
    required this.session,
    super.key,
  });

  final Library library;
  final Session session;

  @override
  State<AssemblyScreen> createState() => _AssemblyScreenState();
}

class _AssemblyScreenState extends State<AssemblyScreen> {
  bool _computing = false;
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
    // is dropped rather than left on screen describing a selection that has
    // changed underneath it.
    await widget.library.save(
      s.copyWith(
        selection: next,
        integration: s.integration != null && !s.integration!.isStaleFor(next)
            ? s.integration
            : null,
      ),
    );
    setState(() {});
  }

  Future<void> _integrate() async {
    final Session s = _session;
    if (s.selection.isEmpty) return;
    setState(() {
      _computing = true;
      _problem = null;
    });
    try {
      final CouncilSession opened = await openCouncil(
        settings: widget.library.settings,
        sessionId: s.id,
      );
      final Integration? integration = await CouncilRun(
        transport: opened.council,
      ).integrate(s, s.selection);
      if (integration == null) {
        setState(() => _problem = 'The integrator returned nothing readable.');
        return;
      }
      final Session assembled = s.copyWith(integration: integration);
      await widget.library.save(
        assembled.copyWith(pitch: PitchComposer.compose(assembled)),
      );
    } on NoCouncil catch (e) {
      // Honest rather than silent: what a selection becomes together is the
      // one thing on this screen only the council can work out.
      setState(() => _problem = '$e');
    } on Object catch (e) {
      setState(() => _problem = 'The integration could not be computed. $e');
    } finally {
      if (mounted) setState(() => _computing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Session s = _session;
    final Integration? integration = s.integration;

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
            if (s.directions.isEmpty)
              Text(
                'Nothing has been rated yet, so there is nothing to preside '
                'over.',
                style: MiType.prose.copyWith(color: c.inkMuted),
              ),
            const SizedBox(height: MiSpace.lg),
            MiRule(strong: true),
            const SizedBox(height: MiSpace.lg),
            Text(
              'What the set becomes',
              style: MiType.title.copyWith(color: c.ink),
            ),
            const SizedBox(height: MiSpace.sm),
            if (integration == null)
              Text(
                s.selection.isEmpty
                    ? 'Select at least one direction. Integration is computed '
                          'across the whole selection, so there is nothing to '
                          'compute across yet.'
                    : 'The selection has changed. What it becomes together has '
                          'to be worked out again — only the council can do '
                          'that, and it is the part worth waiting for.',
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
                      '${_title(s, i.a)} and ${_title(s, i.b)} — ${i.because}',
                  style: MiType.caption,
                ),
              for (final Interaction i in integration.conflicts)
                MiRecord(
                  label: 'Conflicts',
                  value:
                      '${_title(s, i.a)} and ${_title(s, i.b)} — ${i.because}',
                  style: MiType.caption,
                ),
            ],
            const SizedBox(height: MiSpace.lg),
            if (_problem != null) ...<Widget>[
              Text(_problem!, style: MiType.body.copyWith(color: c.warning)),
              const SizedBox(height: MiSpace.md),
            ],
            MiButton(
              label: integration == null
                  ? 'Compute what they become'
                  : 'Compute it again',
              busy: _computing,
              onPressed: s.selection.isEmpty || _computing ? null : _integrate,
            kind: MiButtonKind.primary,),
            const SizedBox(height: MiSpace.xxl),
          ],
        ),
      ),
    );
  }

  String _title(Session s, String id) => s.directionById(id)?.title ?? id;

  Widget _row(MiColors c, Direction d, bool selected) => InkWell(
    onTap: () => _toggle(d.id),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: MiSpace.lg,
            child: Text(
              selected ? '×' : '',
              style: MiType.body.copyWith(color: c.ink),
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
  );
}
