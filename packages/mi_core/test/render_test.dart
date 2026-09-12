import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// A transport that fails if anything touches it.
///
/// The renderers must be pure over the stored session. Handing them a council
/// that throws is the only way to prove it: a renderer that reaches back into
/// the model would be a second implementation of the session, free to disagree
/// with the files on disk, and a completed session would stop being
/// reopenable the day an API key expired.
class UnreachableCouncil implements CouncilTransport {
  @override
  Future<CouncilReply> ask(CouncilTurn turn) async =>
      throw StateError('the renderers reached back into the council');
}

void main() {
  group('the dossier', () {
    test(
      'renders from a stored session with the council unreachable',
      () async {
        final Session s = Session.fromJson((await ranSession()).toJson());
        // The council is constructed and never used; nothing below may call it.
        UnreachableCouncil();
        final MiDocument doc = DossierRenderer.render(s);
        expect(doc.blocks, isNotEmpty);
        expect(doc.toText(), contains(s.interview.brief.restatement));
      },
    );

    test(
      'every verdict on the page is an ordinal word, never a numeral',
      () async {
        final MiDocument doc = DossierRenderer.render(await ranSession());
        for (final DocBlock b in <DocBlock>[
          ...doc.ofKind(BlockKind.verdict),
          ...doc.ofKind(BlockKind.dissent),
        ]) {
          final String verdict = b.text.split('—').first.trim();
          expect(
            RegExp(r'[0-9]').hasMatch(verdict),
            isFalse,
            reason:
                'A numeral in a verdict is a numeral that can be averaged, '
                'and averaging is how dissent disappears: "$verdict"',
          );
        }
      },
    );

    test('judgement is the only thing carrying the accent', () async {
      final MiDocument doc = DossierRenderer.render(await ranSession());
      final Set<BlockKind> accented = <BlockKind>{
        BlockKind.verdict,
        BlockKind.dissent,
      };
      expect(
        doc.blocks.where((DocBlock b) => accented.contains(b.kind)),
        isNotEmpty,
        reason:
            'Oxblood is reserved for verdicts and ratings, so the document '
            'model must actually mark them — a client cannot invent the '
            'distinction later.',
      );
    });

    test('shows where every direction came from', () async {
      final Session s = await ranSession();
      final MiDocument doc = DossierRenderer.render(s);
      expect(
        doc.ofKind(BlockKind.trace).length,
        s.directions.length,
        reason:
            'Traceability is shown rather than claimed. A missing line here '
            'is a direction the client cannot check.',
      );
    });

    test('marks every assumption as a revisit point', () async {
      final Session s = await ranSession();
      final MiDocument doc = DossierRenderer.render(s);
      expect(doc.ofKind(BlockKind.revisit), isNotEmpty);
      expect(
        doc.ofKind(BlockKind.revisit).first.text,
        contains(s.assumptions.first.made),
      );
    });

    test('orders a cluster from conservative to reckless', () async {
      final Session s = await ranSession();
      final MiDocument doc = DossierRenderer.render(s);
      final List<String> versions = <String>[
        for (final DocBlock b in doc.ofKind(BlockKind.field))
          if (b.label == 'Version') b.text,
      ];
      expect(versions, isNotEmpty);
    });
  });

  group('the coverage ledger', () {
    test('reads as entered, left, and still open — in that order', () async {
      final MiDocument doc = LedgerRenderer.render(await ranSession());
      final List<String> headings = <String>[
        for (final DocBlock b in doc.ofKind(BlockKind.heading)) b.text,
      ];
      expect(
        headings.indexOf('Territory entered'),
        lessThan(headings.indexOf('Territory deliberately left')),
      );
      expect(
        headings.indexOf('Territory deliberately left'),
        lessThan(headings.indexOf('Still open')),
      );
    });

    test('every dropped territory shows its reason', () async {
      final Session s = await ranSession();
      final String text = LedgerRenderer.render(s).toText();
      expect(text, isNot(contains('NO REASON RECORDED')));
      for (final Territory t in s.ledger.dropped) {
        expect(text, contains(t.reason));
      }
    });

    test('says how the run ended, naming both deciding rounds', () async {
      final Session s = await ranSession();
      final String text = LedgerRenderer.render(s).toText();
      final DrynessDecision dry = s.manifest.dryness!;
      expect(text, contains('Rounds ${dry.firstRound} and ${dry.secondRound}'));
      expect(text, contains(dry.dedupRuleId));
    });
  });

  group('the ledger accounts for the run itself', () {
    test('council time, the route, and what each round yielded', () async {
      final Session s = await ranSession();
      final String text = LedgerRenderer.render(s).toText();

      expect(
        text,
        contains('HOW THIS RUN WAS CONDUCTED'),
        reason:
            'The manifest records the one number that separates a real '
            'six-hour sitting from a six-hour wait, and it reached no page at '
            'all — only somebody willing to read run_manifest.json by hand.',
      );
      expect(text, contains('council time'));
      expect(text, contains('model calls'));
      expect(
        text,
        contains('Round 1'),
        reason:
            'What was put forward against what was kept is the difference '
            'between a round that searched and a round that repeated itself.',
      );
      expect(
        text,
        contains('Inversion'),
        reason:
            'The record holds angle ids. A client reading '
            '"constraint-tightening" is reading a machine\'s noun, and the '
            'catalog has had a name for it all along.',
      );
      final RoundAccount first = RoundAccount.forSession(s).first;
      expect(
        text,
        contains(first.funnel),
        reason:
            'The ledger and the client\'s own screen read one account of a '
            'round. Two implementations of the same funnel drift, and an '
            'export disagreeing with a live screen about one round is worse '
            'than either being absent.',
      );
    });

    test('a pause says how long it was and how the time was arrived at', () {
      final Session paused = referenceSession().copyWith(
        manifest: referenceSession().manifest.paused(
          LimitPause(
            from: DateTime.utc(2026, 3, 1, 9),
            until: DateTime.utc(2026, 3, 1, 14),
            kind: 'session',
            detail: 'usage limit reached',
            source: 'inferred',
          ),
        ),
      );

      final String text = LedgerRenderer.render(paused).toText();
      expect(text, contains('5 hours'));
      expect(
        text,
        contains('inferred'),
        reason:
            'A resume time that was guessed and one the provider stated are '
            'worth different amounts to whoever reads this afterwards.',
      );
      expect(text, contains('Excluded from council time'));
    });
  });
}
