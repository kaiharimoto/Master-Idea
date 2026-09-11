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
/// it. What there is instead: territory accumulating, round by round, the
/// round in progress counted as far as it has got, what every call is for
/// and what they have cost, and a plain statement of the only thing that can
/// end it.
///
/// Nothing on this screen asks the client to stay. That is what a client
/// relationship with a council requires: their work is at the beginning and
/// the end, never in the middle. What they may do in the middle is pause it,
/// because the calls are theirs to pay for.
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
        final bool here = sitting.isBusy && !elsewhere;
        // The session as the run has it, not as the store has it. The store
        // moves only at barriers, and a round at the largest tier is an hour
        // in which nothing on a barrier-fed screen would move at all.
        final Session shown = here ? (sitting.live ?? open) : open;
        final RunManifest m = shown.manifest;
        final RoundProgress? progress = here ? sitting.progress : null;

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
                      SittingPhase.paused || SittingPhase.held => c.warning,
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
                      _count(c, 'Rounds closed', '${shown.rounds.length}'),
                      _count(
                        c,
                        'Directions held',
                        '${shown.directions.length}',
                      ),
                      _count(c, 'Verdicts recorded', '${shown.ratings.length}'),
                      _count(
                        c,
                        'Territory mapped',
                        '${shown.ledger.territories.length}',
                      ),
                      _count(c, 'Model calls', _thousands(m.calls.length)),
                      _count(
                        c,
                        'Tokens',
                        m.calls.isEmpty
                            ? '0'
                            : m.tokensIn == 0 && m.tokensOut == 0
                            ? 'not reported'
                            : '${_thousands(m.tokensIn)} in · '
                                  '${_thousands(m.tokensOut)} out',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MiSpace.md),

                // The round in progress, as far as it has got. Every figure
                // here is a count of something that has happened; the one
                // total that is known — the angles seated — is the only one
                // written as "of".
                if (progress != null) ...<Widget>[
                  MiPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Round ${progress.round} in progress',
                          style: MiType.body.copyWith(
                            color: c.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: MiSpace.sm),
                        Wrap(
                          spacing: MiSpace.xxl,
                          runSpacing: MiSpace.md,
                          children: <Widget>[
                            _count(
                              c,
                              'Angles back',
                              '${progress.anglesBack} of ${progress.breadth}'
                                  '${progress.exhausted == 0 ? '' : ' · ${progress.exhausted} exhausted'}',
                            ),
                            _count(
                              c,
                              'Kept this round',
                              '${progress.kept} · ${progress.judged} judged',
                            ),
                            _count(
                              c,
                              'Calls this round',
                              _thousands(progress.calls),
                            ),
                          ],
                        ),
                        const SizedBox(height: MiSpace.sm),
                        Text(
                          _inFlight(sitting.inFlight),
                          style: MiType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],

                if (sitting.isHeld && here) ...<Widget>[
                  MiPanel(
                    accent: c.warning,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Paused by you. Nothing new is being sent to the '
                          'council.',
                          style: MiType.body.copyWith(color: c.ink),
                        ),
                        const SizedBox(height: MiSpace.xs),
                        Text(
                          '${_stillOut(sitting.inFlight)} The round picks up '
                          'exactly where it was when you continue, and the '
                          'time paused is not counted as council time.',
                          style: MiType.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MiSpace.md),
                ] else if (sitting.pausedUntil != null) ...<Widget>[
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
                              'nothing new. You can pause it at any time.'
                        : 'On a phone every turn is carried by hand: the app '
                              'gives you what to send and takes back what comes '
                              'of it. A sitting here is never unattended, which '
                              'is why the smallest tier is the honest one.',
                    style: MiType.caption.copyWith(color: c.inkMuted),
                  ),
                ] else ...<Widget>[
                  if (sitting.isHeld)
                    MiButton(
                      label: 'Continue the sitting',
                      kind: MiButtonKind.primary,
                      expand: true,
                      onPressed: sitting.release,
                    )
                  else
                    MiButton(
                      label: 'Pause the sitting',
                      expand: true,
                      onPressed: sitting.hold,
                    ),
                  const SizedBox(height: MiSpace.sm),
                  MiButton(
                    label: 'Stop the sitting',
                    kind: MiButtonKind.quiet,
                    expand: true,
                    onPressed: () async {
                      final bool stop = await showMiConfirm(
                        context,
                        title: 'Stop the sitting?',
                        body:
                            'Every round that has closed is kept, and the '
                            'sitting resumes from there whenever you open it '
                            'again. The round in progress is lost — to keep '
                            'it, pause instead.',
                        action: 'Stop it',
                      );
                      if (stop) sitting.stop();
                    },
                  ),
                ],

                const SizedBox(height: MiSpace.lg),
                const MiRule(),
                // What the calls are, in the arithmetic the run itself uses,
                // so a client watching a counter climb knows what it counts.
                // An expectation, never a limit: nothing here can end a round.
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
                  child: Text(
                    _howCallsAreSpent(shown.template),
                    style: MiType.caption.copyWith(color: c.inkMuted),
                  ),
                ),
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

  Widget _count(MiColors c, String label, String value) => MiField(
    label: label,
    child: Text(value, style: MiType.numeric.copyWith(color: c.ink)),
  );

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';

  static String _thousands(int n) {
    final String s = '$n';
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  /// What the seats out with the council are doing, in words.
  static String _inFlight(Map<String, int> flying) {
    if (flying.isEmpty) return 'Nothing is out with the council right now.';
    const Map<String, String> doing = <String, String>{
      'propose': 'proposing',
      'challenge': 'challenging',
      'rate': 'rating',
      'dissent': 'weighing a dissent',
      'map': 'mapping the territory',
      'integrate': 'integrating',
    };
    final List<String> parts = <String>[
      for (final MapEntry<String, int> e in flying.entries)
        '${e.value} ${doing[e.key] ?? e.key}',
    ];
    return 'Out with the council now: ${parts.join(', ')}.';
  }

  static String _stillOut(Map<String, int> flying) {
    final int n = flying.values.fold(0, (int a, int b) => a + b);
    if (n == 0) return 'Nothing is out with the council.';
    return '$n turn${n == 1 ? '' : 's'} already out ${n == 1 ? 'is' : 'are'} '
        'finishing and will be kept.';
  }

  /// The cost of a round, in the run's own arithmetic.
  static String _howCallsAreSpent(HarnessTemplate t) {
    final int dims = ratingDimensions.length;
    return 'How the calls are spent. A round seats ${t.angleBreadth} angles, '
        'each a separate Claude process asked for up to '
        '${CouncilRun.wantedPerAngle} directions from its own angle, blind to '
        'the others. A direction that is new is challenged once, rated on '
        '$dims dimensions by a fresh seat each, and every rating is offered a '
        'dissent — ${CouncilRun.callsPerDirection} calls per kept direction, '
        'so a round can run to '
        '${_thousands(CouncilRun.mostCallsInRound(t.angleBreadth))} calls. '
        'A proposal already held is refused before it is judged, which is why '
        'later rounds cost far less than the first. The sitting ends only '
        'when two consecutive rounds keep nothing new, so it always runs at '
        'least two rounds past its last discovery.';
  }

  String _status(Sitting s, {required bool elsewhere}) {
    if (elsewhere) return 'Sitting elsewhere';
    return switch (s.phase) {
      SittingPhase.idle => 'The council is not sitting',
      SittingPhase.deliberating => 'The council is deliberating',
      SittingPhase.waitingForHand => 'Waiting to be carried',
      SittingPhase.paused => 'Waiting out a provider limit',
      SittingPhase.held => 'Paused by you',
      SittingPhase.finished => 'The sitting has run dry',
      SittingPhase.failed => 'The sitting could not proceed',
    };
  }
}
