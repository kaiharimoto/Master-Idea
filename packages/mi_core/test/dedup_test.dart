import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

Direction _d(String id, String statement, String mechanism) => Direction(
  id: id,
  clusterId: 'c',
  clusterName: 'Cluster',
  ambition: Ambition.ambitious,
  title: 'Title of $id',
  statement: statement,
  mechanism: mechanism,
  proposedBy: 'prospector#1.1',
  round: 1,
  angleId: 'inversion',
  trace: const TraceLink(answerModuleId: 'raw-idea', quote: 'the idea'),
);

void main() {
  group('what counts as something the council already has', () {
    final List<Direction> held = <Direction>[
      _d(
        'd-0001',
        'Hand the client a case file instead of a conversation, so the '
            'deliberation happens while they are away.',
        'The council writes to a session directory the client reads '
            'afterwards; no stage waits on input.',
      ),
    ];

    test('the same move in different words is refused', () {
      final DedupVerdict v = DedupRule.test(
        'Give the client a case file rather than a conversation, so the '
        'deliberation happens while the client is away. The council writes '
        'into a session directory the client reads afterwards and no stage '
        'waits on input.',
        held,
      );
      expect(v.isDuplicate, isTrue);
      expect(v.duplicateOf, 'd-0001');
    });

    test('a genuinely different move is kept', () {
      final DedupVerdict v = DedupRule.test(
        'Charge for the index rather than the archive, so the artefact can be '
        'given away entirely. Each buyer gets an index regenerated against '
        'their own question.',
        held,
      );
      expect(v.isDuplicate, isFalse);
    });

    test('the title carries no weight', () {
      final DedupVerdict sameTitle = DedupRule.test(
        'Title of d-0001. Refuse every direction that cannot name its own '
        'failure mode, and drop the rest of the round.',
        held,
      );
      expect(
        sameTitle.isDuplicate,
        isFalse,
        reason:
            'Two proposers who find the same move rarely choose the same '
            'title and always describe the same mechanism, so the title is '
            'the one part carrying no signal.',
      );
    });

    test('every rejection names the rule that made it', () {
      final DedupVerdict v = DedupRule.test(held.first.substance, held);
      expect(v.ruleId, DedupRule.currentRuleId);
      final DedupRejection r = v.asRejection(
        candidateTitle: 'x',
        candidateSubstance: held.first.substance,
      );
      expect(r.ruleId, contains('jaccard'));
      expect(r.similarity, greaterThan(DedupRule.threshold));
    });
  });
}
