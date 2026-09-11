import 'dart:convert';

import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

void main() {
  group('a stored session is the whole session', () {
    test('everything written is read back', () async {
      final Session ran = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());
      // With a client hold on the manifest, which a run driven by a scripted
      // council never places on its own.
      final Session s = ran.copyWith(
        manifest: ran.manifest.held(
          Hold(
            from: DateTime.utc(2026, 3, 1, 9, 30),
            until: DateTime.utc(2026, 3, 1, 9, 45),
          ),
        ),
      );

      final Session back = Session.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>,
      );

      expect(back.directions.length, s.directions.length);
      expect(back.ratings.length, s.ratings.length);
      expect(back.rounds.length, s.rounds.length);
      expect(back.assumptions.length, s.assumptions.length);
      expect(back.ledger.territories.length, s.ledger.territories.length);
      expect(back.manifest.calls.length, s.manifest.calls.length);
      expect(back.interview.brief.hash, s.interview.brief.hash);

      // The fields a reload is most likely to quietly lose: the context a
      // rater was shown, the dissent held against a verdict, and the dryness
      // decision. A field that is persisted and never read back is a field
      // that was not persisted.
      expect(
        back.ratings.first.context.shownText,
        s.ratings.first.context.shownText,
      );
      final Rating disputed = s.ratings.firstWhere((Rating r) => r.isDisputed);
      final Rating disputedBack = back.ratings.firstWhere(
        (Rating r) =>
            r.directionId == disputed.directionId &&
            r.dimensionId == disputed.dimensionId,
      );
      expect(
        disputedBack.dissents.first.because,
        disputed.dissents.first.because,
      );
      expect(
        back.manifest.dryness!.secondAngleSet,
        s.manifest.dryness!.secondAngleSet,
      );
      expect(back.manifest.councilTime, s.manifest.councilTime);
      expect(
        back.manifest.holds.length,
        s.manifest.holds.length,
        reason:
            'A hold that did not survive the round trip would put its '
            'minutes back into council time on the next read.',
      );
    });

    test(
      'the round record keeps what was refused as well as what was kept',
      () async {
        final Session s = await CouncilRun(
          transport: ScriptedCouncil(unsourcedInRound: 1),
          clock: FakeClock(),
        ).deliberate(referenceSession());
        final Session back = Session.fromJson(s.toJson());

        final List<Refusal> before = <Refusal>[
          for (final RoundRecord r in s.rounds) ...r.refusals,
        ];
        final List<Refusal> after = <Refusal>[
          for (final RoundRecord r in back.rounds) ...r.refusals,
        ];
        expect(after.length, before.length);
        expect(after.first.reason, before.first.reason);
      },
    );

    test('the interview is frozen with the answers stored verbatim', () async {
      final Session s = await CouncilRun(
        transport: ScriptedCouncil(),
        clock: FakeClock(),
      ).deliberate(referenceSession());
      final Session back = Session.fromJson(s.toJson());

      for (final InterviewAnswer a in s.interview.answers) {
        expect(
          back.interview.answerFor(a.moduleId)!.text,
          a.text,
          reason:
              'A paraphrase stored here would make every traceability link '
              'point at the tool\'s own words.',
        );
      }
      expect(InterviewGate.canOpenRun(back.interview), isTrue);
    });
  });

  group('the interview gate', () {
    test('refuses a run with no declared unknowns', () {
      final InterviewRecord record = referenceInterview();
      final InterviewRecord noLicence = InterviewRecord(
        profileId: record.profileId,
        moduleOrder: record.moduleOrder,
        answers: record.answers,
        brief: record.brief,
        unknowns: const <DeclaredUnknown>[],
        verdict: record.verdict,
        closedAt: record.closedAt,
      );
      expect(InterviewGate.canOpenRun(noLicence), isFalse);
      expect(
        InterviewGate.refusals(noLicence).first.reason,
        contains('licence'),
      );
    });

    test('refuses a module that was put and never answered', () {
      final InterviewRecord record = referenceInterview();
      final InterviewRecord holed = InterviewRecord(
        profileId: record.profileId,
        moduleOrder: record.moduleOrder,
        answers: record.answers.skip(1).toList(),
        brief: record.brief,
        unknowns: record.unknowns,
        verdict: record.verdict,
        closedAt: record.closedAt,
      );
      expect(InterviewGate.canOpenRun(holed), isFalse);
    });
  });

  group('naming a session', () {
    test('is short enough to recognise in a list', () {
      const String brief =
          'An essay arguing that unattended machine work is only trustworthy '
          'when its reasoning is auditable afterwards by someone who was not '
          'there. It is aimed at people who already build with these tools.';
      final String title = SessionTitle.from(brief);
      expect(title.length, lessThanOrEqualTo(57));
      expect(title, startsWith('An essay arguing'));
      expect(
        SessionTitle.slug(title).length,
        lessThan(60),
        reason:
            'The slug becomes a directory name, and the first attempt made '
            'one out of a whole sentence.',
      );
    });

    test('leaves a short brief alone', () {
      expect(
        SessionTitle.from('A song about leaving.'),
        'A song about leaving',
      );
    });

    test('never returns nothing', () {
      expect(SessionTitle.from('   '), 'Untitled session');
      expect(SessionTitle.slug('!!!'), 'session');
    });
  });

  group('a session copy', () {
    test('can drop an integration the selection has outgrown', () {
      final Session s = referenceSession().copyWith(
        selection: <String>['d-0001'],
        integration: Integration(
          forSelection: const <String>['d-0001'],
          becomes: 'One thing rather than three.',
          interactions: const <Interaction>[],
          by: 'integrator#0.1',
          computedAt: DateTime.utc(2026, 3, 1, 12),
        ),
        pitch: 'A pitch for one direction.',
      );

      final Session changed = s.copyWith(
        selection: const <String>['d-0001', 'd-0002'],
        dropIntegration: true,
        dropPitch: true,
      );

      expect(changed.integration, isNull);
      expect(changed.pitch, isEmpty);
      expect(
        s.integration,
        isNotNull,
        reason: 'The original is untouched; a session is a value.',
      );
    });

    test('leaving them alone is still the default', () {
      final Session s = referenceSession().copyWith(pitch: 'kept');
      expect(s.copyWith(selection: const <String>['d-0001']).pitch, 'kept');
    });
  });

  group('the stored shape', () {
    test('says which version wrote it', () {
      expect(
        referenceSession().toJson()['schema'],
        Session.schema,
        reason:
            'A build that reads files it does not understand should say so, '
            'rather than throwing a cast error from four layers down.',
      );
    });
  });
}
