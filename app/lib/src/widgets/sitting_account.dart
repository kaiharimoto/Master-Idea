import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/sitting.dart';

/// Everything the sitting screen draws about a sitting that is under way or
/// has been.
///
/// **All of it reads the stored session**, never the run's event list. The
/// events are memory: `Sitting.begin` clears them and closing the app throws
/// them away, which is how a client came back to ninety-six directions, five
/// hundred and seventy-six verdicts and twelve hundred model calls under the
/// words "Nothing yet."
String thousands(int n) {
  final String s = '$n';
  final StringBuffer b = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// The one number the screen leads with, and what it is made of.
class KeptSoFar extends StatelessWidget {
  const KeptSoFar({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final RunManifest m = session.manifest;
    final int tokens = m.inputAllIn + m.tokensOut;

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            thousands(session.directions.length),
            style: MiType.display.copyWith(color: c.ink),
          ),
          Text(
            session.directions.length == 1
                ? 'direction held'
                : 'directions held',
            style: MiType.body.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: MiSpace.sm),
          Text(
            <String>[
              '${thousands(session.ratings.length)} verdicts',
              '${thousands(m.calls.length)} calls',
              if (m.calls.isEmpty)
                'nothing spent yet'
              else if (tokens == 0)
                'tokens not reported by this route'
              else
                '${thousands(tokens)} tokens',
            ].join(' · '),
            style: MiType.caption.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// What each round kept, round by round.
///
/// **The honest shape of progress.** A sitting ends when two rounds in a row
/// keep nothing new, so the approach to nothing *is* the progress, and it can
/// be shown without anyone predicting anything: the bars are what already
/// happened, and the line underneath states the rule that ends it. No
/// fraction, no percentage and no completion estimate appears here or
/// anywhere near here — decision 0003.
class WhatEachRoundKept extends StatelessWidget {
  const WhatEachRoundKept({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final List<RoundAccount> rounds = RoundAccount.forSession(session);
    final LowerBounds bounds = LowerBounds.forSession(session);

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MiEyebrow('What each round kept'),
          const SizedBox(height: MiSpace.md),
          if (rounds.isEmpty)
            Text(
              'No round has closed yet. A round is a barrier: nothing is '
              'written down until every angle seated in it has come back, '
              'so the first one is the longest.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            )
          else ...<Widget>[
            MiColumns(
              data: <MiColumn>[
                for (final RoundAccount a in rounds)
                  MiColumn('${a.number}', a.kept),
              ],
              semanticLabel: <String>[
                for (final RoundAccount a in rounds)
                  'round ${a.number} kept ${a.kept}',
              ].join(', '),
            ),
            const SizedBox(height: MiSpace.md),
            Text(
              bounds.endSentence,
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The round that is open right now.
class RoundUnderWay extends StatelessWidget {
  const RoundUnderWay({
    required this.progress,
    required this.inFlight,
    super.key,
  });

  final RoundProgress progress;
  final Map<String, int> inFlight;

  static const Map<String, String> _doing = <String, String>{
    'propose': 'searching',
    'challenge': 'challenging',
    'rate': 'rating',
    'dissent': 'weighing a dissent',
    'map': 'mapping the ground',
    'integrate': 'drawing it together',
  };

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final List<String> out = <String>[
      for (final MapEntry<String, int> e in inFlight.entries)
        '${e.value} ${_doing[e.key] ?? e.key}',
    ];

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MiEyebrow('Round ${progress.round}, under way'),
          const SizedBox(height: MiSpace.md),
          MiFanIn(
            total: progress.breadth,
            back: progress.anglesBack,
            exhausted: progress.exhausted,
            note:
                '${progress.anglesBack} of ${progress.breadth} angles back'
                '${progress.exhausted == 0 ? '' : ', ${progress.exhausted} with nothing left'}',
          ),
          const SizedBox(height: MiSpace.sm),
          Text(
            out.isEmpty
                ? 'Nothing is out with the council this second.'
                : 'Out now: ${out.join(' · ')}.',
            style: MiType.caption.copyWith(color: c.inkMuted),
          ),
          if (progress.kept > 0 || progress.calls > 0) ...<Widget>[
            const SizedBox(height: MiSpace.md),
            MiBars(
              data: <MiBar>[
                MiBar('kept so far', progress.kept),
                MiBar('fully judged', progress.judged),
                MiBar('calls made', progress.calls),
              ],
              semanticLabel:
                  '${progress.kept} kept, ${progress.judged} judged, '
                  '${progress.calls} calls',
            ),
          ],
        ],
      ),
    );
  }
}

/// Where the thinking has gone: the clusters, and the ground covered.
class WhereTheThinkingHasGone extends StatelessWidget {
  const WhereTheThinkingHasGone({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Map<String, List<Direction>> clusters = session.clusters;
    final List<MapEntry<String, List<Direction>>> ranked =
        clusters.entries.toList()..sort(
          (
            MapEntry<String, List<Direction>> a,
            MapEntry<String, List<Direction>> b,
          ) => b.value.length.compareTo(a.value.length),
        );
    final CoverageLedger ledger = session.ledger;

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MiEyebrow('Where the thinking has gone'),
          const SizedBox(height: MiSpace.md),
          if (ranked.isEmpty)
            Text(
              'Nothing has been kept yet, so there is no shape to show.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            )
          else
            MiBars(
              data: <MiBar>[
                for (final MapEntry<String, List<Direction>> e in ranked.take(
                  5,
                ))
                  MiBar(e.value.first.clusterName, e.value.length),
              ],
              semanticLabel: 'directions by cluster',
            ),
          const SizedBox(height: MiSpace.lg),
          Text(
            'The ground itself',
            style: MiType.caption.copyWith(color: c.ink),
          ),
          const SizedBox(height: MiSpace.xs),
          MiSplitBar(
            parts: <MiSplit>[
              MiSplit('entered', ledger.explored.length),
              MiSplit('left aside', ledger.dropped.length),
              MiSplit('still open', ledger.gaps.length),
            ],
            semanticLabel: 'coverage of the mapped ground',
          ),
          const SizedBox(height: MiSpace.xs),
          Text(
            'The cartographer writes down what ground the council has '
            'entered, what it deliberately left, and what nobody has reached '
            'yet. A direction can point at one of those open patches instead '
            'of at something you said in the interview.',
            style: MiType.caption.copyWith(color: c.inkFaint),
          ),
        ],
      ),
    );
  }
}

/// The ideas themselves, newest first.
class KeptMostRecently extends StatelessWidget {
  const KeptMostRecently({required this.session, this.show = 8, super.key});

  final Session session;
  final int show;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    // Acceptance order reversed, so this is genuinely the most recent.
    // Deliberately not sorted by rating: a verdict is an ordinal word
    // precisely so that it cannot be ranked, and sorting by one would
    // reintroduce the averaging the whole program refuses.
    final List<Direction> recent = session.directions.reversed
        .take(show)
        .toList();

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MiEyebrow('Kept most recently'),
          const SizedBox(height: MiSpace.md),
          for (final Direction d in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: MiSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(d.title, style: MiType.body.copyWith(color: c.ink)),
                  Text(
                    <String>[
                      d.clusterName,
                      angleByIdOrNull(d.angleId)?.name ?? d.angleId,
                      'round ${d.round}',
                    ].join(' · '),
                    style: MiType.caption.copyWith(color: c.inkFaint),
                  ),
                ],
              ),
            ),
          Text(
            session.directions.isEmpty
                ? 'Nothing kept yet.'
                : 'All ${thousands(session.directions.length)} are in the '
                      'case file.',
            style: MiType.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// What the invariant suite says about the session as it stands.
class AuditStanding extends StatefulWidget {
  const AuditStanding({
    required this.sitting,
    required this.session,
    super.key,
  });

  final Sitting sitting;
  final Session session;

  @override
  State<AuditStanding> createState() => _AuditStandingState();
}

class _AuditStandingState extends State<AuditStanding> {
  @override
  void initState() {
    super.initState();
    _askIfStale();
  }

  @override
  void didUpdateWidget(AuditStanding old) {
    super.didUpdateWidget(old);
    _askIfStale();
  }

  void _askIfStale() {
    if (widget.sitting.auditIsFor(widget.session)) return;
    if (widget.session.rounds.isEmpty) return;
    // After the frame, never during it. The suite is pure, but the thing that
    // holds its answer notifies listeners, and a listener rebuilding the tree
    // it is being built inside is how a screen locks up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.sitting.takeAudit(widget.session);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final InvariantReport? report = widget.sitting.audit;
    if (report == null) return const SizedBox.shrink();

    final bool running = widget.session.manifest.dryness == null;
    final int traceability = report.forInvariant(Invariant.traceability).length;
    final int independence = report
        .forInvariant(Invariant.independentRating)
        .length;
    // Everything except the one finding a live run always carries.
    final int answerable = traceability + independence;

    String count(int n) => switch (n) {
      0 => 'holds',
      1 => 'one to look at',
      _ => '$n to look at',
    };

    final LowerBounds bounds = LowerBounds.forSession(widget.session);
    final bool mappedLate =
        bounds.mapFirstDrawnAtRound != null && bounds.mapFirstDrawnAtRound! > 1;

    return MiPanel(
      // Warning rather than danger, always. A healthy sitting carries findings
      // that later rounds close, and red on a run that is going well teaches
      // the client to stop reading this panel.
      accent: answerable == 0 ? null : c.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: MiEyebrow('The audit as it stands')),
              MiTag(
                answerable == 0
                    ? 'nothing to answer for'
                    : '$answerable to answer for',
                tone: answerable == 0 ? c.success : c.warning,
              ),
            ],
          ),
          const SizedBox(height: MiSpace.md),
          MiRecord(
            label: 'Every idea traces to something you said',
            value: count(traceability),
          ),
          MiRecord(
            label: 'Nothing judged its own idea',
            value: count(independence),
          ),
          MiRecord(
            label: 'It ran until it ran dry',
            value: running ? 'decided when the sitting ends' : 'holds',
          ),
          const SizedBox(height: MiSpace.sm),
          Text(
            'Checked against the stored session alone, after round '
            '${widget.sitting.auditedAfterRounds} — no council, no network.',
            style: MiType.caption.copyWith(color: c.inkFaint),
          ),
          if (mappedLate) ...<Widget>[
            const SizedBox(height: MiSpace.sm),
            Text(
              'This sitting drew its first map at round '
              '${bounds.mapFirstDrawnAtRound}, so the rounds before it could '
              'only point back at the interview. Newer sittings describe the '
              'ground before the first round opens; that change cannot reach '
              'back into this one.',
              style: MiType.caption.copyWith(color: c.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// What is still owed, stated as a floor.
class WhatHappensNext extends StatelessWidget {
  const WhatHappensNext({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final LowerBounds b = LowerBounds.forSession(session);

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MiEyebrow('What happens next'),
          const SizedBox(height: MiSpace.md),
          MiRecord(
            label: 'The ground is mapped again',
            value: 'after round ${b.nextMapAtRound}',
          ),
          MiRecord(
            label: 'This cannot end before',
            value: 'round ${b.noEarlierThanRound}',
          ),
          const SizedBox(height: MiSpace.sm),
          Text(
            b.endSentence,
            style: MiType.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// Every round that has closed, in the order they closed.
class RoundHistory extends StatelessWidget {
  const RoundHistory({required this.session, super.key});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final List<RoundAccount> rounds = RoundAccount.forSession(
      session,
    ).reversed.toList();
    if (rounds.isEmpty) return const SizedBox.shrink();

    return MiPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const MiEyebrow('Round by round'),
          const SizedBox(height: MiSpace.sm),
          for (final RoundAccount a in rounds)
            MiDisclosure(
              label: 'Round ${a.number}',
              trailingNote: '${a.kept} kept',
              initiallyOpen: a.number == rounds.first.number,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  MiBars(
                    data: <MiBar>[
                      MiBar('put forward', a.proposed),
                      MiBar('refused', a.refused),
                      MiBar('already held', a.duplicates),
                      MiBar('kept', a.kept),
                    ],
                    labelWidth: 96,
                    semanticLabel: 'round ${a.number}: ${a.funnel}',
                  ),
                  const SizedBox(height: MiSpace.sm),
                  MiRecord(label: 'Angles', value: a.angleNames.join(' · ')),
                  MiRecord(label: 'Came back', value: a.attendance),
                  MiRecord(
                    label: 'Took',
                    value:
                        '${a.tookInWords}, ${thousands(a.calls)} model calls',
                  ),
                  if (a.drewTheMap)
                    MiRecord(
                      label: 'Ground opened up',
                      value: '${a.gapsNamed} new patches nobody has reached',
                    ),
                  if (a.unreadLines > 0) ...<Widget>[
                    const SizedBox(height: MiSpace.xs),
                    Text(
                      '${a.unreadLines} lines came back unreadable. An angle '
                      'that answers unreadably is the one thing that can look '
                      'like an angle with nothing left.',
                      style: MiType.caption.copyWith(color: c.warning),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
