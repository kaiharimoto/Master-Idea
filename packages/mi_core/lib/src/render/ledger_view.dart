import '../session/ledger.dart';
import '../session/manifest.dart';
import '../session/round.dart';
import '../session/session.dart';
import 'document.dart';
import 'round_account.dart';

/// The completeness map, rendered so it can be read in about thirty seconds.
///
/// Three sections, always in this order: what was entered, what was
/// deliberately left, and what is still open. The order is the argument — a
/// ledger that opened with its gaps would read as an apology, and one that
/// hid them at the bottom would be the completeness theatre this whole
/// apparatus exists to replace.
abstract final class LedgerRenderer {
  static MiDocument render(Session s) {
    final CoverageLedger l = s.ledger;
    final List<DocBlock> b = <DocBlock>[
      const DocBlock(BlockKind.title, 'Coverage ledger'),
      DocBlock(
        BlockKind.field,
        '${l.explored.length} entered · ${l.dropped.length} left · '
        '${l.gaps.length} open',
        label: 'The map',
      ),
      const DocBlock(BlockKind.rule, ''),
      const DocBlock(BlockKind.heading, 'Territory entered'),
    ];

    for (final Territory t in l.explored) {
      b
        ..add(DocBlock(BlockKind.subheading, t.name))
        ..add(DocBlock(BlockKind.paragraph, t.description))
        ..add(
          DocBlock(
            BlockKind.field,
            t.filledByDirectionIds.isEmpty
                ? 'no direction cites this territory'
                : t.filledByDirectionIds.join(', '),
            label: 'Filled by',
          ),
        );
    }

    b.add(const DocBlock(BlockKind.heading, 'Territory deliberately left'));
    if (l.dropped.isEmpty) {
      b.add(
        const DocBlock(
          BlockKind.paragraph,
          'Nothing was dropped. Every territory the cartographer named was '
          'entered.',
        ),
      );
    }
    for (final Territory t in l.dropped) {
      b
        ..add(DocBlock(BlockKind.subheading, t.name))
        ..add(DocBlock(BlockKind.paragraph, t.description))
        ..add(
          DocBlock(
            BlockKind.field,
            t.reason.isEmpty ? 'NO REASON RECORDED' : t.reason,
            label: 'Because',
          ),
        );
    }

    b.add(const DocBlock(BlockKind.heading, 'Still open'));
    if (l.gaps.isEmpty) {
      b.add(
        const DocBlock(
          BlockKind.paragraph,
          'No gap is open. Every gap the cartographer named was filled before '
          'the run went dry.',
        ),
      );
    }
    for (final Territory t in l.gaps) {
      b
        ..add(DocBlock(BlockKind.subheading, t.name))
        ..add(DocBlock(BlockKind.paragraph, t.description))
        ..add(
          DocBlock(
            BlockKind.field,
            'named at the round ${t.firstWrittenInRound} barrier',
            label: 'Opened',
          ),
        );
    }

    final DrynessDecision? dry = s.manifest.dryness;
    b
      ..add(const DocBlock(BlockKind.rule, ''))
      ..add(const DocBlock(BlockKind.heading, 'How the run ended'));
    if (dry == null) {
      b.add(
        const DocBlock(
          BlockKind.paragraph,
          'This run has not ended. It ends when two consecutive rounds at the '
          'same breadth return nothing new, and not for any other reason.',
        ),
      );
    } else {
      b
        ..add(
          DocBlock(
            BlockKind.paragraph,
            'Rounds ${dry.firstRound} and ${dry.secondRound} both returned '
            'nothing the council did not already have. Round '
            '${dry.firstRound} searched ${dry.firstAngleSet.join(', ')}. '
            'Round ${dry.secondRound} searched '
            '${dry.secondAngleSet.join(', ')}.',
          ),
        )
        ..add(DocBlock(BlockKind.field, dry.dedupRuleId, label: 'Judged by'));
      if (dry.wentDryBelowFloor) {
        b.add(
          DocBlock(
            BlockKind.paragraph,
            'The run went dry at ${dry.directionCount} directions, below the '
            '${dry.floorAtTier} this tier expects. The tier was too large for '
            'the idea; the session is re-tiered downward rather than padded to '
            'the number.',
          ),
        );
      }
    }

    // Everything the run lost, in one place. A budget drop that is only
    // visible by comparing two round records is a drop nobody will find.
    final List<Refusal> refusals = <Refusal>[
      for (final RoundRecord r in s.rounds) ...r.refusals,
    ];
    if (refusals.isNotEmpty) {
      b.add(const DocBlock(BlockKind.heading, 'Refused during the run'));
      for (final Refusal r in refusals) {
        b.add(
          DocBlock(
            BlockKind.item,
            '${r.candidateTitle} — ${r.kind}: ${r.reason}',
          ),
        );
      }
    }

    _howItWasConducted(s, b);

    return MiDocument(b);
  }

  /// The run's own account of itself.
  ///
  /// The manifest records council time, every pause, every model call and
  /// which transport drove it, and none of it reached a page — so the one
  /// number that separates a real six-hour sitting from a six-hour wait was
  /// visible only to somebody willing to read `run_manifest.json` by hand.
  /// It belongs in the ledger rather than the dossier: the dossier is the
  /// judgement, and this is the evidence that the judgement was worked for.
  static void _howItWasConducted(Session s, List<DocBlock> b) {
    final RunManifest m = s.manifest;
    b
      ..add(const DocBlock(BlockKind.rule, ''))
      ..add(const DocBlock(BlockKind.heading, 'How this run was conducted'))
      ..add(
        DocBlock(
          BlockKind.field,
          m.transport == 'handover'
              ? 'carried by hand, one turn at a time'
              : 'driven through the Claude CLI, unattended',
          label: 'Route',
        ),
      )
      ..add(
        DocBlock(
          BlockKind.field,
          '${spellDuration(m.councilTime)} of council time'
          '${m.pauses.isEmpty ? '' : ', inside ${spellDuration(m.wallClock)} of wall clock'}',
          label: 'Time',
        ),
      )
      ..add(
        DocBlock(
          BlockKind.field,
          m.tokensIn == 0 && m.tokensOut == 0
              ? '${m.calls.length} model calls, usage not reported by this '
                    'transport'
              : '${m.calls.length} model calls, ${m.tokensIn} tokens in and '
                    '${m.tokensOut} out',
          label: 'Calls',
        ),
      );

    for (final LimitPause p in m.pauses) {
      b.add(
        DocBlock(
          BlockKind.item,
          'Paused ${spellDuration(p.length)} on a ${p.kind} limit, resuming at a time '
          'that was ${p.source}. Excluded from council time.',
        ),
      );
    }
    for (final Hold h in m.holds) {
      b.add(
        DocBlock(
          BlockKind.item,
          'Held ${spellDuration(h.length)} by the client. Nothing new was sent while '
          'it stood, and the round it interrupted was completed after. '
          'Excluded from council time.',
        ),
      );
    }

    // What each round actually did, read from the same account the client's
    // own screen reads. Two implementations of one funnel drift, and an
    // exported record disagreeing with a live screen about the same round is
    // worse than either of them being absent.
    for (final RoundAccount a in RoundAccount.forSession(s)) {
      b
        ..add(DocBlock(BlockKind.subheading, 'Round ${a.number}'))
        ..add(
          DocBlock(
            BlockKind.field,
            a.angleNames.join(' · '),
            label: 'Angles seated',
          ),
        )
        ..add(DocBlock(BlockKind.field, a.attendance, label: 'Came back'))
        ..add(DocBlock(BlockKind.field, a.funnel, label: 'Yield'))
        ..add(
          DocBlock(
            BlockKind.field,
            a.drewTheMap
                ? '${a.gapsNamed} named at this barrier'
                : 'the cartographer did not sit this round',
            label: 'Gaps',
          ),
        )
        ..add(
          DocBlock(
            BlockKind.field,
            '${a.calls} model calls over ${a.tookInWords}'
            '${a.inputAllIn == 0 ? '' : ', ${a.inputAllIn} tokens in '
                      'and ${a.tokensOut} out'}',
            label: 'Cost',
          ),
        );
      // Lines nobody could read are named beside the round they were in. An
      // angle that said nothing and an angle whose reply was unreadable are
      // the difference between a run that finished and a run that was ended
      // by a parser, and only one of them is dryness.
      if (a.unreadLines > 0) {
        b.add(
          DocBlock(
            BlockKind.field,
            '${a.unreadLines} — an angle answering unreadably is the one '
            'thing that can counterfeit dryness',
            label: 'Unreadable lines',
          ),
        );
      }
      for (final AngleAccount x in a.angles) {
        b.add(DocBlock(BlockKind.item, x.line));
      }
    }

    final List<String> thin = s.clustersNotSpanning;
    if (thin.isNotEmpty) {
      b
        ..add(
          const DocBlock(
            BlockKind.subheading,
            'Clusters that do not span the range',
          ),
        )
        ..add(
          const DocBlock(
            BlockKind.paragraph,
            'A count of directions says nothing about whether the client was '
            'offered a real choice. These clusters hold no conservative, no '
            'ambitious or no reckless member, so within them there is a '
            'decision the council did not put.',
          ),
        );
      for (final String id in thin) {
        b.add(DocBlock(BlockKind.item, id));
      }
    }
  }

  /// Durations as words. A number of seconds is a measurement; this is a
  /// document.
}
