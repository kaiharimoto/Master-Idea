import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/naming.dart';
import '../store/sitting.dart';
import '../widgets/carry_panel.dart';

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
class RunScreen extends StatelessWidget {
  const RunScreen({
    required this.library,
    required this.sitting,
    required this.session,
    required this.onFinished,
    required this.onOpenSettings,
    super.key,
  });

  final Library library;
  final Sitting sitting;
  final Session session;
  final VoidCallback onFinished;

  /// Where to send a client whose machine has no council on it. A failure that
  /// names the fix and cannot reach it is a failure twice.
  final VoidCallback onOpenSettings;

  Future<void> _begin(BuildContext context) async {
    final Session open = library.open ?? session;
    // A sitting that already went dry ended for the only reason this system
    // permits. Re-opening it is a decision, not a button: it runs at least two
    // more rounds of paid model calls and rewrites the dryness decision that
    // is the session's whole claim to have finished.
    if (open.manifest.dryness != null) {
      final bool again = await showMiConfirm(
        context,
        title: 'This sitting already ran dry',
        body:
            'It ended because two consecutive rounds returned nothing new. '
            'Opening it again runs at least two more rounds and replaces that '
            'decision with a new one.',
        action: 'Convene it again',
      );
      if (!again) return;
    }
    // Nothing on this screen probes or writes status on arrival. A region that
    // sets a runner to idle when it opens is a region that can make a live
    // sitting look finished, and the next Run click launches a second council
    // into the same session.
    await sitting.begin(open, library.settings);
    if (context.mounted && sitting.phase == SittingPhase.finished) {
      onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[sitting, library]),
      builder: (BuildContext context, _) {
        final Session open = library.open ?? session;
        final CouncilTurn? carrying = sitting.hand?.waiting;
        // The sitting is one per app, and the client may open another session
        // while it runs. Saying whose it is beats showing counts that do not
        // move against a session the council is not looking at.
        final bool elsewhere =
            sitting.isBusy &&
            sitting.sessionId != null &&
            sitting.sessionId != open.id;

        return SingleChildScrollView(
          child: MiLeaf(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MiSectionHeader(
                  title: tierName(open.interview.verdict),
                  subtitle: tierExpectation(open.interview.verdict),
                  trailing: MiTag(
                    _status(sitting, elsewhere: elsewhere),
                    tone: switch (sitting.phase) {
                      SittingPhase.failed => c.danger,
                      SittingPhase.finished => c.success,
                      SittingPhase.paused => c.warning,
                      _ => c.inkMuted,
                    },
                  ),
                ),
                const SizedBox(height: MiSpace.lg),

                if (elsewhere) ...<Widget>[
                  MiPanel(
                    child: Text(
                      'The council is sitting on another session on this '
                      'device. It carries on wherever you are; this one waits.',
                      style: MiType.prose.copyWith(color: c.inkMuted),
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],

                // What has actually accumulated. Counts of things that exist,
                // never a fraction of a total nobody can know: the sitting
                // ends when it runs dry, so there is no denominator — and a
                // progress bar here would be a claim nobody can make.
                MiPanel(
                  child: Wrap(
                    spacing: MiSpace.xxl,
                    runSpacing: MiSpace.md,
                    children: <Widget>[
                      _count(c, 'Rounds closed', open.rounds.length),
                      _count(c, 'Directions held', open.directions.length),
                      _count(c, 'Verdicts recorded', open.ratings.length),
                      _count(
                        c,
                        'Territory mapped',
                        open.ledger.territories.length,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MiSpace.lg),

                if (sitting.pausedUntil != null) ...<Widget>[
                  MiPanel(
                    accent: c.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Waiting out the provider’s limit until '
                          '${_clock(sitting.pausedUntil!)}.',
                          style: MiType.body.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MiSpace.xs),
                        Text(
                          'The sitting resumes on its own. A limit is not the '
                          'council falling silent, so this wait is excluded '
                          'from council time and cannot end the run.',
                          style: MiType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],

                if (carrying != null) ...<Widget>[
                  CarryPanel(hand: sitting.hand!, turn: carrying),
                  const SizedBox(height: MiSpace.lg),
                ],

                if (sitting.problem != null) ...<Widget>[
                  MiPanel(
                    accent: c.danger,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          sitting.problem!,
                          style: MiType.prose.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MiSpace.sm),
                        Text(
                          'Every round that closed is stored. Fix this and '
                          'open the sitting again — it resumes from the '
                          'barrier it reached.',
                          style: MiType.caption.copyWith(color: c.inkMuted),
                        ),
                        if (sitting.route == SittingRoute.cli) ...<Widget>[
                          const SizedBox(height: MiSpace.sm),
                          MiButton(
                            label: 'Settings',
                            onPressed: onOpenSettings,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],

                if (!sitting.isBusy) ...<Widget>[
                  MiButton(
                    label: switch ((
                      open.rounds.isEmpty,
                      open.manifest.dryness,
                    )) {
                      (true, _) => 'Open the sitting',
                      (false, null) =>
                        'Resume from round ${open.rounds.length + 1}',
                      (false, _) => 'Convene it again',
                    },
                    kind: MiButtonKind.primary,
                    expand: true,
                    onPressed: elsewhere ? null : () => _begin(context),
                  ),
                  const SizedBox(height: MiSpace.sm),
                  Text(
                    sitting.canDrive
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
                ] else
                  MiButton(
                    label: 'Stop the sitting',
                    expand: true,
                    onPressed: () async {
                      final bool stop = await showMiConfirm(
                        context,
                        title: 'Stop the sitting?',
                        body:
                            'Every round that has closed is kept, and the '
                            'sitting resumes from there whenever you open it '
                            'again. The round in progress is lost.',
                        action: 'Stop it',
                      );
                      if (stop) sitting.stop();
                    },
                  ),

                const SizedBox(height: MiSpace.lg),
                const MiRule(),
                // One line of it out here, because a screen whose only sign of
                // life is behind a closed disclosure is indistinguishable from
                // a screen that has hung.
                if (sitting.lastEvent != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
                    child: Text(
                      '${sitting.lastEvent}',
                      style: MiType.mono.copyWith(color: c.inkMuted),
                    ),
                  ),
                MiDisclosure(
                  label: 'What the council has been doing',
                  trailingNote: sitting.events.isEmpty
                      ? null
                      : '${sitting.events.length}',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (sitting.events.isEmpty)
                        Text(
                          'Nothing yet.',
                          style: MiType.caption.copyWith(color: c.inkMuted),
                        ),
                      for (final RunEvent e in sitting.events.reversed.take(40))
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

  Widget _count(MiColors c, String label, int n) => MiField(
    label: label,
    child: Text('$n', style: MiType.numeric.copyWith(color: c.ink)),
  );

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  String _status(Sitting s, {required bool elsewhere}) {
    if (elsewhere) return 'Sitting elsewhere';
    return switch (s.phase) {
      SittingPhase.idle => 'The council is not sitting',
      SittingPhase.deliberating => 'The council is deliberating',
      SittingPhase.waitingForHand => 'Waiting to be carried',
      SittingPhase.paused => 'Waiting out a provider limit',
      SittingPhase.finished => 'The sitting has run dry',
      SittingPhase.failed => 'The sitting could not proceed',
    };
  }
}
