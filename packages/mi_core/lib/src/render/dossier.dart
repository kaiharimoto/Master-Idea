import '../council/dimensions.dart';
import '../interview/interview_gate.dart';
import '../session/direction.dart';
import '../session/rating.dart';
import '../session/session.dart';
import 'document.dart';

/// The case file, read out of the stored session.
///
/// Ordering is deliberate and not alphabetical: clusters in the order the
/// council found them, members within a cluster from conservative to reckless
/// so the range is visible at a glance, and the most contested direction of
/// each cluster first among equals. A dossier sorted by score would be a
/// dossier that had averaged its dissent away to get one.
abstract final class DossierRenderer {
  static MiDocument render(Session s) {
    final List<DocBlock> b = <DocBlock>[
      DocBlock(BlockKind.title, s.title),
      DocBlock(
        BlockKind.field,
        s.interview.verdict.template.name,
        label: 'Sitting',
      ),
      DocBlock(BlockKind.field, s.interview.profileId, label: 'Medium'),
      DocBlock(
        BlockKind.field,
        '${s.directions.length} directions, ${s.clusters.length} clusters',
        label: 'Case file',
      ),
      const DocBlock(BlockKind.rule, ''),
      const DocBlock(BlockKind.heading, 'The brief as approved'),
      DocBlock(BlockKind.paragraph, s.interview.brief.restatement),
    ];

    if (s.interview.unknowns.isNotEmpty) {
      b.add(const DocBlock(BlockKind.heading, 'Declared unknowns'));
      for (final DeclaredUnknown u in s.interview.unknowns) {
        b.add(DocBlock(BlockKind.item, '${u.question}  —  ${u.licence}'));
      }
    }

    s.clusters.forEach((String clusterId, List<Direction> members) {
      final List<Direction> ordered = <Direction>[...members]
        ..sort(
          (Direction x, Direction y) =>
              x.ambition.index.compareTo(y.ambition.index),
        );
      b
        ..add(const DocBlock(BlockKind.rule, ''))
        ..add(DocBlock(BlockKind.heading, members.first.clusterName));
      for (final Direction d in ordered) {
        b.addAll(_direction(s, d));
      }
    });

    return MiDocument(b);
  }

  static List<DocBlock> _direction(Session s, Direction d) {
    final List<DocBlock> b = <DocBlock>[
      DocBlock(BlockKind.subheading, d.title),
      DocBlock(BlockKind.field, d.ambition.name, label: 'Version'),
      DocBlock(BlockKind.paragraph, d.statement),
      DocBlock(BlockKind.field, d.mechanism, label: 'Mechanism'),
    ];

    // Traceability, shown rather than claimed. A dossier where this line is
    // missing is a dossier that failed the invariant, and it should be
    // visibly missing rather than quietly absent.
    b.add(
      DocBlock(
        BlockKind.trace,
        d.trace.answerModuleId != null
            ? 'from the client\'s answer on ${d.trace.answerModuleId}: '
                  '"${d.trace.quote}"'
            : 'from the named gap ${d.trace.gapId}: "${d.trace.quote}"',
        label: 'Traced to',
      ),
    );

    for (final RatingDimension dim in ratingDimensions) {
      for (final Rating r in s.ratingsFor(d.id)) {
        if (r.dimensionId != dim.id) continue;
        b.add(
          DocBlock(
            BlockKind.verdict,
            '${r.verdict} — ${r.because} (${r.ratedBy}, drawing on '
            '${r.vocabularyId})',
            label: dim.name,
          ),
        );
        for (final Dissent dis in r.dissents) {
          b.add(
            DocBlock(
              BlockKind.dissent,
              '${dis.verdict} — ${dis.because} (${dis.by})',
              label: 'Dissent',
            ),
          );
        }
      }
    }

    for (final Challenge c in s.challengesFor(d.id)) {
      b.add(
        DocBlock(
          BlockKind.field,
          '${c.attack} (${c.by})',
          label: c.answered ? 'Challenged' : 'Challenged, fatal',
        ),
      );
    }

    for (final Assumption a in s.assumptionsFor(d.id)) {
      b.add(
        DocBlock(
          BlockKind.revisit,
          a.isLicensed
              ? '${a.made} — assumed against the declared unknown '
                    '"${a.answersUnknownId}". ${a.because}'
              : '${a.made} — assumed with no declared unknown to license it. '
                    '${a.because}',
          label: 'Revisit',
        ),
      );
    }

    return b;
  }
}
