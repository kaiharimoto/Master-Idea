import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('a round is a barrier', () {
    test('every angle in a round searches before the round closes', () async {
      final ScriptedCouncil council = ScriptedCouncil();
      final Session done = await CouncilRun(
        transport: council,
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final RoundRecord first = done.rounds.first;
      expect(
        first.returns.map((AngleReturn r) => r.angleId).toSet(),
        first.angleSet.toSet(),
        reason:
            'A round that closed with an angle unsearched is a round whose '
            '"nothing new came back" means nothing.',
      );
    });

    test('breadth never narrows across the run', () async {
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final Set<int> breadths = done.rounds
          .map((RoundRecord r) => r.breadth)
          .toSet();
      expect(
        breadths.length,
        1,
        reason:
            'Dryness found by looking less hard is a timer with better '
            'manners, so breadth is held constant rather than merely checked.',
      );
    });
  });

  group('the run ends only by going dry', () {
    test('two consecutive quiet rounds end it, and nothing else', () async {
      final ScriptedCouncil council = ScriptedCouncil(silentFromRound: 3);
      final Session done = await CouncilRun(
        transport: council,
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final DrynessDecision dry = done.manifest.dryness!;
      expect(dry.firstRound, 3);
      expect(dry.secondRound, 4);
      expect(
        done.rounds.last.number,
        4,
        reason: 'A round run after dryness would be padding.',
      );
      expect(
        done.rounds
            .where((RoundRecord r) => r.returnedSomethingNew)
            .map((RoundRecord r) => r.number),
        <int>[1, 2],
      );
    });

    test(
      'the decision names both rounds, both angle sets and the rule',
      () async {
        final Session done = await CouncilRun(
          transport: ScriptedCouncil(),
          clock: FakeClock(),
        ).deliberate(referenceSession());

        final DrynessDecision dry = done.manifest.dryness!;
        expect(dry.firstAngleSet, isNotEmpty);
        expect(dry.secondAngleSet.length, dry.firstAngleSet.length);
        expect(
          dry.dedupRuleId,
          DedupRule.currentRuleId,
          reason:
              'A dryness decision read next year has to say which rule judged '
              'it, or two sessions get compared across a change to it.',
        );
      },
    );

    test('going dry below the tier floor is recorded, not run off', () async {
      // An assize expects a hundred directions; this council has a dozen in it.
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession(templateId: 'assize'));

      expect(done.manifest.dryness!.wentDryBelowFloor, isTrue);
      expect(
        done.directions.length,
        lessThan(templateById('assize').directionFloor),
        reason:
            'The run stopped where the idea ran out, which is the only '
            'permitted end condition even when it lands below the floor.',
      );
    });
  });

  group('what the run refuses', () {
    test('a direction citing an answer nobody was asked is refused', () async {
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(unsourcedInRound: 1),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final List<Refusal> refusals = <Refusal>[
        for (final RoundRecord r in done.rounds) ...r.refusals,
      ];
      expect(refusals, isNotEmpty);
      expect(refusals.first.kind, 'unsourced');
      expect(
        done.directions.where(
          (Direction d) =>
              d.trace.answerModuleId == 'module-that-was-never-put',
        ),
        isEmpty,
        reason:
            'An unsourced direction must not reach the dossier at all — the '
            'invariant is enforced during the run, not discovered after it.',
      );
    });

    test(
      'a re-proposal of something already held is logged, not stored',
      () async {
        final Session done = await CouncilRun(
          transport: ScriptedCouncil(silentFromRound: 4),
          clock: FakeClock(),
        ).deliberate(referenceSession());

        final List<DedupRejection> rejections = <DedupRejection>[
          for (final RoundRecord r in done.rounds) ...r.rejections,
        ];
        expect(
          rejections,
          isNotEmpty,
          reason:
              'Rounds two and three re-search angles already searched, so the '
              'deduplicator must have had something to reject.',
        );
        for (final DedupRejection r in rejections) {
          expect(done.directionById(r.againstDirectionId), isNotNull);
          expect(r.ruleId, DedupRule.currentRuleId);
        }
      },
    );
  });

  group('a provider limit is a pause, never silence', () {
    test(
      'the wait is logged, excluded from council time, and the call retried',
      () async {
        final FakeClock clock = FakeClock();
        final Session done = await CouncilRun(
          transport: ScriptedCouncil(pauseOnCall: 2),
          clock: clock,
        ).deliberate(referenceSession());

        expect(
          clock.waited,
          isNotEmpty,
          reason: 'The run must actually wait out a limit, not skip past it.',
        );
        expect(done.manifest.pauses, hasLength(1));
        expect(done.manifest.pauses.first.kind, 'session');
        expect(
          done.manifest.councilTime,
          lessThan(done.manifest.wallClock),
          reason:
              'A session that waited five hours for a limit did not deliberate '
              'for five hours, and a manifest that said so would make a six-hour '
              'run indistinguishable from a six-hour wait.',
        );
        expect(
          done.directions,
          isNotEmpty,
          reason: 'The paused call is retried, so the search is not lost.',
        );
      },
    );
  });

  group('the record a run leaves', () {
    test('every model call is accounted for in the manifest', () async {
      final ScriptedCouncil council = ScriptedCouncil();
      final Session done = await CouncilRun(
        transport: council,
        clock: FakeClock(),
      ).deliberate(referenceSession());

      expect(done.manifest.calls.length, council.calls);
      expect(done.manifest.tokensIn, greaterThan(0));
      expect(
        done.manifest.calls.map((ModelCall c) => c.purpose).toSet(),
        containsAll(<String>['propose', 'challenge', 'rate']),
      );
    });

    test('a dropped territory always carries its reason', () async {
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      expect(done.ledger.dropped, isNotEmpty);
      expect(done.ledger.unexplainedDrops, isEmpty);
    });

    test(
      'assumptions are recorded against the unknown that licensed them',
      () async {
        final Session done = await CouncilRun(
          transport: ScriptedCouncil(),
          clock: FakeClock(),
        ).deliberate(referenceSession());

        expect(done.assumptions, isNotEmpty);
        expect(done.assumptions.first.answersUnknownId, 'u-interruption');
        expect(done.assumptions.first.affects, isNotEmpty);
      },
    );
  });

  group('no rater is ever the proposer', () {
    test('at instance level, across a whole run', () async {
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      expect(done.ratings, isNotEmpty);
      for (final Rating r in done.ratings) {
        final Direction d = done.directionById(r.directionId)!;
        expect(r.ratedBy, isNot(d.proposedBy));
        expect(
          r.context.shownText.contains(d.proposedBy),
          isFalse,
          reason:
              'A rater shown the proposer is rating the advocacy, which is '
              'the invariant broken by transport rather than by code.',
        );
      }
    });

    test(
      'dissent is held by a seat, with a reason, or not recorded at all',
      () async {
        final Session done = await CouncilRun(
          transport: ScriptedCouncil(),
          clock: FakeClock(),
        ).deliberate(referenceSession());

        final List<Rating> disputed = done.ratings
            .where((Rating r) => r.isDisputed)
            .toList();
        expect(disputed, isNotEmpty);
        for (final Rating r in disputed) {
          for (final Dissent d in r.dissents) {
            expect(d.verdict, isNot(r.verdict));
            expect(d.because.trim(), isNotEmpty);
            expect(AgentInstance.parse(d.by).roleId, 'dissenter');
          }
        }
      },
    );
  });

  group('angles running concurrently', () {
    test('cannot both accept the same convergent proposal', () async {
      // Every angle in the scripted council proposes the same idea first, the
      // way a real council converges. Deduplication happens without an await
      // in the middle for exactly this reason: a yield there lets two angles
      // both accept it, and the dossier silently doubles.
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final Iterable<Direction> convergent = done.directions.where(
        (Direction d) => d.title == 'Direction the-obvious-one',
      );
      expect(convergent, hasLength(1));
    });
  });

  group('what an interrupted run leaves behind', () {
    test('every closed round reaches the barrier callback', () async {
      final List<int> stored = <int>[];
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
        onBarrier: (Session s) async => stored.add(s.rounds.length),
      ).deliberate(referenceSession());

      expect(
        stored,
        <int>[1, 2, 3, 4, 4],
        reason:
            'A round is stored when it closes, and the dryness decision once '
            'more at the end — a run saved only when it finishes is a run '
            'that loses six hours to a power cut.',
      );
      expect(done.rounds, hasLength(4));
    });

    test('a stop ends the run and keeps what closed before it', () async {
      final List<Session> stored = <Session>[];
      final CouncilRun run = CouncilRun(
        // Late enough that a round has closed, so there is something to keep.
        transport: ScriptedCouncil(stopOnCall: 100),
        clock: FakeClock(),
        onBarrier: (Session s) async => stored.add(s),
      );

      await expectLater(
        run.deliberate(referenceSession()),
        throwsA(isA<CouncilStopped>()),
        reason:
            'A stop is the client, not the provider. Waiting it out would '
            'put the same turn back on screen forever.',
      );
      expect(stored, isNotEmpty);
      expect(run.sessionSoFar!.rounds, isNotEmpty);
      expect(
        run.sessionSoFar!.manifest.dryness,
        isNull,
        reason: 'A sitting that was stopped has emphatically not run dry.',
      );
    });

    test('a failure that is not a limit ends the run at once', () async {
      final CouncilRun run = CouncilRun(
        transport: ScriptedCouncil(failOnCall: 2),
        clock: FakeClock(),
      );

      await expectLater(
        run.deliberate(referenceSession()),
        throwsA(isA<CouncilUnavailable>()),
        reason:
            'Not logged in does not lift by waiting. A run that waits it out '
            'loses every search and then records itself as having gone dry.',
      );
      expect(
        run.sessionSoFar!.ledger.dropped,
        isEmpty,
        reason: 'Nothing was deliberately left: the council never got to look.',
      );
    });

    test('silence already on the record still counts', () async {
      // A session as an interruption leaves it: one round that found
      // something, one that found nothing, and no dryness decision — which is
      // exactly what is on disk when a sitting is stopped or fails after a
      // quiet round.
      final Session ran = await CouncilRun(
        transport: ScriptedCouncil(silentFromRound: 2),
        clock: FakeClock(),
      ).deliberate(referenceSession());
      final Session interrupted = ran.copyWith(
        rounds: ran.rounds.take(2).toList(),
        manifest: RunManifest(
          sessionId: ran.id,
          templateId: ran.manifest.templateId,
          tier: ran.manifest.tier,
          transport: 'cli',
          startedAt: ran.manifest.startedAt,
        ),
      );
      expect(interrupted.rounds.last.returnedSomethingNew, isFalse);

      final Session done = await CouncilRun(
        transport: ScriptedCouncil(silentFromRound: 2),
        clock: FakeClock(),
      ).deliberate(interrupted);

      expect(
        done.manifest.dryness!.firstRound,
        interrupted.rounds.last.number,
        reason:
            'Dryness is a property of the session, not of one process\'s '
            'memory. A resumed run counting from zero re-searches a round '
            'that was already searched and found empty, and charges for it.',
      );
    });

    test('a resumed run never re-issues a direction id', () async {
      final Session first = await CouncilRun(
        transport: ScriptedCouncil(silentFromRound: 2),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      // Resumed from a session that already holds directions, the way the app
      // resumes one that was interrupted.
      final Session second =
          await CouncilRun(
            transport: ScriptedCouncil(silentFromRound: 3),
            clock: FakeClock(),
          ).deliberate(
            first.copyWith(
              manifest: RunManifest(
                sessionId: first.id,
                templateId: first.manifest.templateId,
                tier: first.manifest.tier,
                transport: 'cli',
                startedAt: first.manifest.startedAt,
              ),
            ),
          );

      final List<String> ids = <String>[
        for (final Direction d in second.directions) d.id,
      ];
      expect(
        ids.toSet().length,
        ids.length,
        reason:
            'The store writes a rating file once and never rewrites it, so a '
            'reissued id loses the new direction\'s verdicts silently.',
      );
    });
  });

  group('a limit is waited out for as long as it takes', () {
    test('more times than any retry budget would have allowed', () async {
      final FakeClock clock = FakeClock();
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(pauseUntilCall: 6),
        clock: clock,
      ).deliberate(referenceSession());

      expect(
        clock.waited.length,
        greaterThan(3),
        reason:
            'A limit always lifts. A run that gave up on the fourth wait '
            'would record the provider\'s silence as the council\'s.',
      );
      expect(done.directions, isNotEmpty);
      expect(done.manifest.pauses.first.source, 'stated');
    });
  });

  group('what a round says about itself', () {
    test('an exhausted angle is not a misread one', () async {
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(silentFromRound: 2),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final RoundRecord quiet = done.rounds.firstWhere(
        (RoundRecord r) => r.number == 2,
      );
      expect(
        quiet.returns.every((AngleReturn r) => r.exhausted),
        isTrue,
        reason:
            'mi-none is what takes a run to dryness, and a round of silence '
            'that was really a round nobody could read is a run ended by a '
            'parser.',
      );
      expect(
        done.rounds.first.returns.every((AngleReturn r) => r.exhausted),
        isFalse,
      );
    });

    test('a direction that cites a gap fills it on the map', () async {
      final Session done = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());

      final List<Territory> filled = done.ledger.territories
          .where((Territory t) => t.filledByDirectionIds.isNotEmpty)
          .toList();
      expect(
        filled,
        isNotEmpty,
        reason:
            'Without this the ledger reports "no direction cites this '
            'territory" for every territory in every session ever produced, '
            'which is the completeness claim reading as unearned.',
      );
      for (final Territory t in filled) {
        for (final String id in t.filledByDirectionIds) {
          expect(done.directionById(id), isNotNull);
        }
      }
    });
  });

  group('the angle rotation', () {
    test('reaches every angle in the catalog at the narrowest breadth', () {
      final Set<String> seen = <String>{};
      for (int round = 1; round <= 12; round++) {
        seen.addAll(
          CouncilRun.angleSetFor(
            round: round,
            breadth: 4,
            profile: profileById('essay'),
          ),
        );
      }
      expect(
        seen.length,
        explorationAngles.length,
        reason:
            'An angle that no session ever searches is a family member that '
            'never executed, which the brief treats as a failure rather than '
            'an unused option.',
      );
    });

    test('the profile leads the first round and never narrows the catalog', () {
      final DomainProfile song = profileById('song');
      expect(
        CouncilRun.angleSetFor(round: 1, breadth: 4, profile: song),
        song.favouredAngles,
      );
    });
  });
}
