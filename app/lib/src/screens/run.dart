import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/sitting.dart';
import '../transport/council_session.dart';
import '../transport/handover_council.dart';

/// The council, sitting.
///
/// **Quiet and grave.** There is no spinner here, no percentage, no agent
/// chatter and no personality performing for an audience — because a sitting
/// runs for hours and none of those things would be telling the truth about
/// it. What there is instead: territory accumulating, round by round, and a
/// plain statement of the only thing that can end it.
///
/// Nothing on this screen asks the client to stay. That is what a client
/// relationship with a council requires: their work is at the beginning and
/// the end, never in the middle.
class RunScreen extends StatefulWidget {
  const RunScreen({
    required this.library,
    required this.sitting,
    required this.session,
    required this.onFinished,
    super.key,
  });

  final Library library;
  final Sitting sitting;
  final Session session;
  final VoidCallback onFinished;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  final TextEditingController _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _begin() async {
    // Nothing on this screen probes or writes status on arrival. A region that
    // sets a runner to idle when it opens is a region that can make a live
    // sitting look finished, and the next Run click launches a second council
    // into the same session.
    await widget.sitting.begin(widget.session, widget.library.settings);
    if (mounted && widget.sitting.phase == SittingPhase.finished) {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: widget.sitting,
      builder: (BuildContext context, _) {
        final Sitting s = widget.sitting;
        final Session session =
            widget.library.open ?? widget.session;
        final CouncilTurn? carrying = s.hand?.waiting;

        return SingleChildScrollView(
          child: MiLeaf(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MiSectionHeader(
                  title: session.interview.verdict.template.name,
                  subtitle: session.interview.verdict.template.expectation,
                  trailing: MiTag(
                    _status(s),
                    tone: switch (s.phase) {
                      SittingPhase.failed => c.danger,
                      SittingPhase.finished => c.success,
                      _ => c.inkMuted,
                    },
                  ),
                ),
                const SizedBox(height: MiSpace.lg),

                // What has actually accumulated. Counts of things that exist,
                // never a fraction of a total nobody can know: the sitting
                // ends when it runs dry, so there is no denominator — and a
                // progress bar here would be a claim nobody can make.
                MiPanel(
                  child: Wrap(
                    spacing: MiSpace.xxl,
                    runSpacing: MiSpace.md,
                    children: <Widget>[
                      MiField(
                        label: 'Rounds closed',
                        child: Text(
                          '${session.rounds.length}',
                          style: MiType.numeric.copyWith(color: c.ink),
                        ),
                      ),
                      MiField(
                        label: 'Directions held',
                        child: Text(
                          '${session.directions.length}',
                          style: MiType.numeric.copyWith(color: c.ink),
                        ),
                      ),
                      MiField(
                        label: 'Verdicts recorded',
                        child: Text(
                          '${session.ratings.length}',
                          style: MiType.numeric.copyWith(color: c.ink),
                        ),
                      ),
                      MiField(
                        label: 'Territory mapped',
                        child: Text(
                          '${session.ledger.territories.length}',
                          style: MiType.numeric.copyWith(color: c.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MiSpace.lg),

                if (carrying != null) ..._carry(c, s, carrying),

                if (s.problem != null) ...<Widget>[
                  MiPanel(
                    accent: c.danger,
                    child: Text(
                      s.problem!,
                      style: MiType.prose.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],

                if (!s.isBusy) ...<Widget>[
                  MiButton(
                    label: session.rounds.isEmpty
                        ? 'Open the sitting'
                        : 'Resume from round ${session.rounds.length + 1}',
                    kind: MiButtonKind.primary,
                    expand: true,
                    onPressed: _begin,
                  ),
                  const SizedBox(height: MiSpace.sm),
                  Text(
                    canDriveCouncil
                        ? 'The council deliberates on its own. You may watch, '
                              'and you may leave — it never waits on you, and '
                              'it ends only when two consecutive rounds return '
                              'nothing new.'
                        : 'On a phone every turn is carried by hand: the app '
                              'gives you what to send and takes back what comes '
                              'of it. A sitting here is never unattended, which '
                              'is why the smallest tier is the honest one.',
                    style: MiType.caption.copyWith(color: c.inkMuted),
                  ),
                ] else if (s.route == SittingRoute.handover)
                  MiButton(
                    label: 'Stop the sitting',
                    expand: true,
                    onPressed: s.stop,
                  ),

                const SizedBox(height: MiSpace.lg),
                const MiRule(),
                MiDisclosure(
                  label: 'What the council has been doing',
                  trailingNote: s.events.isEmpty ? null : '${s.events.length}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (s.events.isEmpty)
                        Text(
                          'Nothing yet.',
                          style: MiType.caption.copyWith(color: c.inkMuted),
                        ),
                      for (final RunEvent e in s.events.reversed.take(40))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '$e',
                            style: MiType.mono.copyWith(color: c.inkMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: MiSpace.xxl),
              ],
            ),
          ),
        );
      },
    );
  }

  String _status(Sitting s) => switch (s.phase) {
    SittingPhase.idle => 'The council is not sitting',
    SittingPhase.deliberating => 'The council is deliberating',
    SittingPhase.waitingForHand => 'Waiting to be carried',
    SittingPhase.finished => 'The sitting has run dry',
    SittingPhase.failed => 'The sitting could not proceed',
  };

  /// The handover route: one turn out, one reply back.
  List<Widget> _carry(MiColors c, Sitting s, CouncilTurn turn) {
    final HandoverCouncil? hand = s.hand;
    return <Widget>[
      MiPanel(
        accent: c.ink,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                MiTag(turn.purpose),
                const SizedBox(width: MiSpace.sm),
                Expanded(
                  child: Text(
                    turn.agent.id,
                    style: MiType.mono.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MiSpace.md),
            MiButton(
              label: 'Copy this turn',
              kind: MiButtonKind.primary,
              expand: true,
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: turn.prompt)),
            ),
            const SizedBox(height: MiSpace.sm),
            Text(
              'Paste it into your chat app, then bring the whole reply back '
              'here. A reply that arrived by hand has no more authority than '
              'one that came down a pipe: it is read by the same parser and '
              'held to the same invariants.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: MiSpace.md),
            MiWriting(
              controller: _reply,
              hint: 'Everything the reply said.',
              onSubmit: () => _bringBack(hand),
            ),
            const SizedBox(height: MiSpace.sm),
            MiButton(
              label: 'Bring it back',
              expand: true,
              onPressed: () => _bringBack(hand),
            ),
          ],
        ),
      ),
      const SizedBox(height: MiSpace.lg),
    ];
  }

  void _bringBack(HandoverCouncil? hand) {
    if (_reply.text.trim().isEmpty) return;
    hand?.receive(_reply.text);
    _reply.clear();
  }
}
