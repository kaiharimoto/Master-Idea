import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// A real run, used as the honest baseline every negative test starts from.
Future<Session> goodSession() => CouncilRun(
  transport: ScriptedCouncil(),
  clock: FakeClock(),
).deliberate(referenceSession());

void main() {
  group('a session the council actually ran', () {
    test('holds all three invariants', () async {
      final Session s = await goodSession();
      final InvariantReport report = InvariantSuite.run(s);
      expect(report.holds, isTrue, reason: report.summary);
    });

    test('still holds after being written to disk and read back', () async {
      final Session s = await goodSession();
      final Session reopened = Session.fromJson(s.toJson());
      expect(
        InvariantSuite.run(reopened).holds,
        isTrue,
        reason:
            'The suite has to work from stored files alone, or it can only '
            'be run on the day and never next month.',
      );
    });
  });

  // The suite is only worth having if it fails when an invariant is broken.
  // Each test below breaks exactly one thing in a session that was otherwise
  // sound, and asserts that the matching check — and only it — catches it.
  group('the suite has teeth', () {
    test('an unsourced direction fails traceability', () async {
      final Session s = await goodSession();
      final Direction d = s.directions.first;
      final Session broken = s.copyWith(
        directions: <Direction>[
          Direction(
            id: d.id,
            clusterId: d.clusterId,
            clusterName: d.clusterName,
            ambition: d.ambition,
            title: d.title,
            statement: d.statement,
            mechanism: d.mechanism,
            proposedBy: d.proposedBy,
            round: d.round,
            angleId: d.angleId,
            trace: const TraceLink(quote: 'nothing at all'),
          ),
          ...s.directions.skip(1),
        ],
      );

      final InvariantReport r = InvariantSuite.run(broken);
      expect(r.holdsFor(Invariant.traceability), isFalse);
      expect(r.forInvariant(Invariant.traceability).first.subject, d.id);
    });

    test(
      'a gap written in the direction\'s own round fails traceability',
      () async {
        final Session s = await goodSession();
        final Direction d = s.directions.first;
        final Session broken = s.copyWith(
          ledger: s.ledger.add(
            Territory(
              id: 'g-after-the-fact',
              name: 'A gap invented to justify something already written',
              description:
                  'Named in the same round as the direction citing it.',
              status: TerritoryStatus.gap,
              firstWrittenInRound: d.round,
            ),
          ),
          directions: <Direction>[
            Direction(
              id: d.id,
              clusterId: d.clusterId,
              clusterName: d.clusterName,
              ambition: d.ambition,
              title: d.title,
              statement: d.statement,
              mechanism: d.mechanism,
              proposedBy: d.proposedBy,
              round: d.round,
              angleId: d.angleId,
              trace: const TraceLink(
                gapId: 'g-after-the-fact',
                quote: 'the gap it was written to fill',
              ),
            ),
            ...s.directions.skip(1),
          ],
        );

        expect(
          InvariantSuite.run(broken).holdsFor(Invariant.traceability),
          isFalse,
        );
      },
    );

    test(
      'a direction rated by its own proposer fails independent rating',
      () async {
        final Session s = await goodSession();
        final Rating r = s.ratings.first;
        final Direction d = s.directionById(r.directionId)!;
        final Session broken = s.copyWith(
          ratings: <Rating>[
            Rating(
              directionId: r.directionId,
              dimensionId: r.dimensionId,
              verdict: r.verdict,
              vocabularyId: r.vocabularyId,
              ratedBy: d.proposedBy,
              context: r.context,
              because: r.because,
              dissents: r.dissents,
            ),
            ...s.ratings.skip(1),
          ],
        );

        final InvariantReport report = InvariantSuite.run(broken);
        expect(report.holdsFor(Invariant.independentRating), isFalse);
        expect(
          report.holdsFor(Invariant.traceability),
          isTrue,
          reason: 'Breaking one invariant must not smear across the others.',
        );
      },
    );

    test('a rater shown the proposer fails independent rating', () async {
      final Session s = await goodSession();
      final Rating r = s.ratings.first;
      final Direction d = s.directionById(r.directionId)!;
      final Map<String, Object?> json = r.toJson();
      final Map<String, Object?> context =
          json['context']! as Map<String, Object?>;
      context['shownText'] =
          '${context['shownText']}\nProposed by ${d.proposedBy}, who argues '
          'strongly for it.';

      final Session broken = s.copyWith(
        ratings: <Rating>[Rating.fromJson(json), ...s.ratings.skip(1)],
      );
      expect(
        InvariantSuite.run(broken).holdsFor(Invariant.independentRating),
        isFalse,
      );
    });

    test('a numeral in a verdict fails independent rating', () async {
      final Session s = await goodSession();
      final Rating r = s.ratings.first;
      final Map<String, Object?> json = r.toJson()..['verdict'] = '4';
      final Session broken = s.copyWith(
        ratings: <Rating>[Rating.fromJson(json), ...s.ratings.skip(1)],
      );
      expect(
        InvariantSuite.run(broken).holdsFor(Invariant.independentRating),
        isFalse,
      );
    });

    test('manufactured dissent fails independent rating', () async {
      final Session s = await goodSession();
      final Rating r = s.ratings.first;
      final Map<String, Object?> json = r.toJson()
        ..['dissents'] = <Map<String, Object?>>[
          <String, Object?>{
            'by': 'dissenter#1.1',
            'verdict': r.verdict,
            'because': '',
          },
        ];
      final Session broken = s.copyWith(
        ratings: <Rating>[Rating.fromJson(json), ...s.ratings.skip(1)],
      );
      expect(
        InvariantSuite.run(broken).holdsFor(Invariant.independentRating),
        isFalse,
        reason:
            'Dissent that agrees with the record, held for no stated '
            'reason, is dissent generated to satisfy a check.',
      );
    });

    test('a run with no dryness decision fails run-until-dry', () async {
      final Session s = await goodSession();
      final Map<String, Object?> json = s.toJson();
      (json['manifest']! as Map<String, Object?>).remove('dryness');
      expect(
        InvariantSuite.run(
          Session.fromJson(json),
        ).holdsFor(Invariant.runUntilDry),
        isFalse,
      );
    });

    test(
      'a deciding round that returned something new fails run-until-dry',
      () async {
        final Session s = await goodSession();
        final DrynessDecision dry = s.manifest.dryness!;
        final Map<String, Object?> json = s.toJson();
        final List<Object?> rounds = json['rounds']! as List<Object?>;
        for (final Object? r in rounds) {
          final Map<String, Object?> round = r! as Map<String, Object?>;
          if (round['number'] == dry.secondRound) {
            round['newDirectionIds'] = <String>['d-9999'];
          }
        }
        expect(
          InvariantSuite.run(
            Session.fromJson(json),
          ).holdsFor(Invariant.runUntilDry),
          isFalse,
        );
      },
    );

    test('a narrowed deciding round fails run-until-dry', () async {
      final Session s = await goodSession();
      final Map<String, Object?> json = s.toJson();
      final Map<String, Object?> manifest =
          json['manifest']! as Map<String, Object?>;
      final Map<String, Object?> dry =
          manifest['dryness']! as Map<String, Object?>;
      dry['secondAngleSet'] = <String>['inversion'];
      expect(
        InvariantSuite.run(
          Session.fromJson(json),
        ).holdsFor(Invariant.runUntilDry),
        isFalse,
        reason:
            'A run declared dry on a narrower round looked less hard and '
            'called it silence.',
      );
    });

    test(
      'a limit pause across the deciding rounds fails run-until-dry',
      () async {
        final Session s = await goodSession();
        final RoundRecord last = s.rounds.last;
        final Session broken = s.copyWith(
          manifest: s.manifest.paused(
            LimitPause(
              from: last.startedAt.subtract(const Duration(seconds: 1)),
              until: last.endedAt.add(const Duration(seconds: 1)),
              kind: 'rate',
              detail: 'rate limit',
            ),
          ),
        );
        expect(
          InvariantSuite.run(broken).holdsFor(Invariant.runUntilDry),
          isFalse,
          reason:
              'The silence that ended that run was the provider\'s, not the '
              'council\'s.',
        );
      },
    );

    test('a territory dropped with no reason fails run-until-dry', () async {
      final Session s = await goodSession();
      final Session broken = s.copyWith(
        ledger: s.ledger.add(
          const Territory(
            id: 't-quietly-abandoned',
            name: 'Something the run stopped doing',
            description: 'Left without saying why.',
            status: TerritoryStatus.dropped,
            firstWrittenInRound: 1,
          ),
        ),
      );
      expect(
        InvariantSuite.run(broken).holdsFor(Invariant.runUntilDry),
        isFalse,
      );
    });

    test(
      'a run left at a tier it went dry beneath fails run-until-dry',
      () async {
        final Session s = await CouncilRun(
          transport: ScriptedCouncil(),
          clock: FakeClock(),
        ).deliberate(referenceSession(templateId: 'assize'));

        expect(
          InvariantSuite.run(s).holdsFor(Invariant.runUntilDry),
          isFalse,
          reason:
              'Going dry below the floor is legitimate; leaving the session '
              'labelled as an assize afterwards is the lie.',
        );
      },
    );
  });
}
