import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// How a stored round reads back to a person.
///
/// Everything here is pure over files on disk. That is the property the whole
/// account exists for: the client's screen was showing an in-memory list of
/// events that `begin()` clears, so a sitting reopened after ninety-six
/// directions and twelve hundred model calls said the council had done nothing.
void main() {
  RoundRecord roundNamed({
    required int number,
    List<String> angleSet = const <String>['inversion', 'first-principles'],
    List<AngleReturn> returns = const <AngleReturn>[],
    List<String> kept = const <String>['d-0001'],
    List<String> gaps = const <String>[],
  }) => RoundRecord(
    number: number,
    angleSet: angleSet,
    returns: returns,
    rejections: const <DedupRejection>[],
    refusals: const <Refusal>[],
    newDirectionIds: kept,
    gapsNamed: gaps,
    startedAt: DateTime.utc(2026, 3, 1, 9),
    endedAt: DateTime.utc(2026, 3, 1, 9, 40),
  );

  group('a round reads back in words, not in ids', () {
    test('angles are named from the catalog', () async {
      final Session s = await ranSession();
      final RoundAccount a = RoundAccount.forSession(s).first;

      expect(
        a.angleNames,
        isNot(contains('first-principles')),
        reason:
            'The record stores ids because ids are what a run can be audited '
            'against. A client reading one is reading a machine\'s noun.',
      );
      expect(a.angleNames, contains('First principles'));
    });

    test(
      'an angle this build has never heard of prints rather than throws',
      () {
        final RoundAccount a = RoundAccount.of(
          roundNamed(number: 1, angleSet: <String>['an-angle-since-retired']),
          RunManifest(
            sessionId: 's',
            templateId: 'hearing',
            tier: 0,
            transport: 'cli',
            startedAt: DateTime.utc(2026),
          ),
        );

        expect(
          a.angleNames,
          <String>['an-angle-since-retired'],
          reason:
              'A session written by another build can name an angle this '
              'catalog dropped. A lookup that threw while a list of rounds was '
              'being built would take every other session on the screen down '
              'with it.',
        );
      },
    );

    test('a seat is named by the role that sat in it', () {
      final AngleAccount a = AngleAccount.of(
        const AngleReturn(
          angleId: 'inversion',
          by: 'prospector#2.7',
          proposedIds: <String>['a', 'b'],
          keptIds: <String>['d-0001'],
        ),
      );

      expect(a.bySeat, 'a prospector');
      expect(
        AngleAccount.of(
          const AngleReturn(
            angleId: 'inversion',
            by: 'whoever felt like it',
            proposedIds: <String>[],
            keptIds: <String>[],
          ),
        ).bySeat,
        'whoever felt like it',
        reason:
            'An id this council could not have issued is worth showing as it '
            'is. The invariant suite is the thing that must object to it; a '
            'screen only has to stay up.',
      );
    });

    test('an exhausted angle and an unreadable one do not read alike', () {
      AngleAccount account({bool exhausted = false, int unread = 0}) =>
          AngleAccount.of(
            AngleReturn(
              angleId: 'inversion',
              by: 'prospector#1.1',
              proposedIds: const <String>[],
              keptIds: const <String>[],
              exhausted: exhausted,
              unread: List<String>.filled(unread, 'noise'),
            ),
          );

      expect(account(exhausted: true).line, contains('nothing left'));
      expect(account(unread: 3).line, contains('none of it could be read'));
      expect(
        account(exhausted: true).line,
        isNot(account(unread: 3).line),
        reason:
            'One of those is dryness and the other is a run ended by a '
            'parser, and the whole apparatus exists to keep them apart.',
      );
    });
  });

  group('a round is costed from the manifest it was run under', () {
    test('only the calls inside the round count toward it', () async {
      final Session s = await ranSession();
      for (final RoundAccount a in RoundAccount.forSession(s)) {
        final RoundRecord r = s.rounds.firstWhere(
          (RoundRecord x) => x.number == a.number,
        );
        expect(
          a.calls,
          s.manifest.callsBetween(r.startedAt, r.endedAt),
          reason:
              'The manifest is flat, so what a round cost is a derivation '
              'from its own ends rather than a figure stored beside it that '
              'could drift from the calls it claims to count.',
        );
      }
    });
  });

  group('what is still owed is a floor, and never a forecast', () {
    test(
      'a round that kept something puts the earliest end two away',
      () async {
        final Session s = await ranSession();
        final LowerBounds b = LowerBounds.forSession(
          s.copyWith(
            rounds: <RoundRecord>[roundNamed(number: 1)],
            manifest: s.manifest,
          ),
        );

        expect(b.quietRoundsSoFar, 0);
        expect(
          b.noEarlierThanRound,
          3,
          reason:
              'Two consecutive rounds keeping nothing is the only thing that '
              'ends a sitting, so a round that kept something means at least '
              'two more have to run.',
        );
      },
    );

    test('a quiet round brings the floor one closer and no nearer', () async {
      final Session s = await ranSession();
      final LowerBounds b = LowerBounds.forSession(
        s.copyWith(
          rounds: <RoundRecord>[
            roundNamed(number: 1),
            roundNamed(number: 2, kept: const <String>[]),
          ],
        ),
      );

      expect(b.quietRoundsSoFar, 1);
      expect(b.noEarlierThanRound, 3);
      expect(b.endSentence, contains('One more round like it'));
    });

    test('nothing it says can be read as a completion estimate', () async {
      final Session s = await ranSession();
      for (final int keptRounds in <int>[0, 1, 2]) {
        final LowerBounds b = LowerBounds.forSession(
          s.copyWith(
            rounds: <RoundRecord>[
              for (int i = 1; i <= keptRounds; i++)
                roundNamed(number: i, kept: const <String>[]),
            ],
          ),
        );
        for (final String said in <String>[b.endSentence, b.mapSentence]) {
          for (final String banned in <String>[
            '%',
            'estimate',
            'remaining',
            'complete',
            'progress',
          ]) {
            expect(
              said.toLowerCase(),
              isNot(contains(banned)),
              reason:
                  'A run that can be ended by a counter will be, and "ran '
                  'until the number" would then be recorded as "ran dry". '
                  'Prose is the one place a ceiling sneaks back in.',
            );
          }
        }
      }
    });

    test('the run itself cannot see the arithmetic that describes it', () {
      final String source = sourceOf('lib/src/run/council_run.dart');

      expect(
        source,
        isNot(contains('LowerBounds')),
        reason:
            'An arithmetic the loop can read is an arithmetic the loop can be '
            'made to obey. These are for the client\'s screen and for nothing '
            'that decides when a round ends.',
      );
    });
  });
}
