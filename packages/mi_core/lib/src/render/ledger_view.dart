import '../session/ledger.dart';
import '../session/round.dart';
import '../session/session.dart';
import 'document.dart';

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

    return MiDocument(b);
  }
}
