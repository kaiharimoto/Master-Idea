import 'dart:io';

import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

void main() {
  group('the council', () {
    test('seats at least the eight the brief requires', () {
      expect(councilRoles.length, greaterThanOrEqualTo(8));
    });

    test('no seat can both advocate and judge', () {
      for (final CouncilRole r in councilRoles) {
        expect(
          r.isSelfJudging,
          isFalse,
          reason:
              '${r.id} could propose a direction and then rate it, which '
              'makes the independent-rating invariant a matter of luck '
              'rather than of structure.',
        );
      }
    });

    test('no two seats share a lens', () {
      final Set<String> lenses = councilRoles
          .map((CouncilRole r) => r.lens)
          .toSet();
      expect(
        lenses.length,
        councilRoles.length,
        reason:
            'A seat that duplicates another inflates the apparent breadth '
            'of a round while finding nothing the first would not have.',
      );
    });

    test('an agent instance id survives a round trip through text', () {
      const AgentInstance a = AgentInstance(
        roleId: 'assessor',
        round: 3,
        ordinal: 12,
      );
      final AgentInstance back = AgentInstance.parse(a.id);
      expect(back, a);
      expect(back.role.id, 'assessor');
    });
  });

  group('the angles', () {
    test('number at least the ten the brief requires', () {
      expect(explorationAngles.length, greaterThanOrEqualTo(10));
    });

    test('each claims something the others structurally cannot find', () {
      final Set<String> claims = explorationAngles
          .map((ExplorationAngle a) => a.findsWhatOthersCannot)
          .toSet();
      expect(claims.length, explorationAngles.length);
      final Set<String> modalities = explorationAngles
          .map((ExplorationAngle a) => a.modality)
          .toSet();
      expect(
        modalities.length,
        explorationAngles.length,
        reason:
            'Angles vary by search modality, not by topic. Ten topics fan '
            'out into the same neighbourhood ten times and report breadth.',
      );
    });

    test('every angle carries an instruction sufficient on its own', () {
      for (final ExplorationAngle a in explorationAngles) {
        expect(
          a.instruction.length,
          greaterThan(80),
          reason:
              '${a.id} is all the context a blind prospector gets about '
              'where to look.',
        );
      }
    });
  });

  group('the rating dimensions', () {
    test('number at least five and catch different failures', () {
      expect(ratingDimensions.length, greaterThanOrEqualTo(5));
      final Set<String> catches = ratingDimensions
          .map((RatingDimension d) => d.catches)
          .toSet();
      expect(
        catches.length,
        ratingDimensions.length,
        reason:
            'Two dimensions that would rise and fall together are one axis '
            'wearing two names.',
      );
    });

    test('every vocabulary is ordinal, closed, and able to reject', () {
      for (final RatingVocabulary v in ratingVocabularies) {
        expect(v.rungs.length, greaterThanOrEqualTo(3));
        expect(v.rungs.toSet().length, v.rungs.length);
        expect(v.contains(v.rejectAtOrBelow), isTrue);
        expect(v.rejects(v.worst), isTrue);
        expect(
          v.rejects(v.best),
          isFalse,
          reason:
              'A vocabulary that rejects everything is as useless as one '
              'that rejects nothing.',
        );
        for (final String rung in v.rungs) {
          expect(
            RegExp(r'[0-9]').hasMatch(rung),
            isFalse,
            reason:
                'A numeral in a verdict invites averaging, and averaging is '
                'how dissent disappears.',
          );
        }
      }
    });

    test(
      'the four named anti-patterns each have a dimension that catches them',
      () {
        final String all = ratingDimensions
            .map((RatingDimension d) => d.catches.toLowerCase())
            .join(' ');
        for (final String pattern in <String>[
          'restatement',
          'consultant ambition',
          'safe incrementalism',
        ]) {
          expect(all, contains(pattern));
        }
      },
    );
  });

  group('the committed vocabularies', () {
    // The critics are given `critics/vocabularies.md` and the code is given
    // `dimensions.dart`, and the two must be the same closed sets. A rubric
    // whose vocabulary moved between cycles could show motion but never
    // progress, so a change to one that is not a change to the other fails
    // here rather than being discovered by a critic reading the wrong ladder.
    test('agree with the catalog, rung for rung', () {
      final File committed = File('../../critics/vocabularies.md');
      expect(
        committed.existsSync(),
        isTrue,
        reason: 'The judgeset is committed before the first review cycle.',
      );
      final String text = committed.readAsStringSync();

      for (final RatingVocabulary v in ratingVocabularies) {
        final String rungs = v.rungs.join(', ');
        final String row =
            '| `' + v.id + '` | ' + rungs + ' | ' + v.rejectAtOrBelow + ' |';
        expect(
          text,
          contains(row),
          reason:
              'critics/vocabularies.md does not carry ' +
              v.id +
              ' as the code defines it.',
        );
      }
    });
  });

  group('the harness templates', () {
    test('cover four tiers with rising breadth and floors', () {
      expect(harnessTemplates.length, greaterThanOrEqualTo(4));
      for (int i = 1; i < harnessTemplates.length; i++) {
        expect(harnessTemplates[i].tier, harnessTemplates[i - 1].tier + 1);
        expect(
          harnessTemplates[i].angleBreadth,
          greaterThan(harnessTemplates[i - 1].angleBreadth),
        );
        expect(
          harnessTemplates[i].directionFloor,
          greaterThan(harnessTemplates[i - 1].directionFloor),
        );
      }
      expect(harnessTemplates.first.directionFloor, 30);
      expect(harnessTemplates.last.directionFloor, greaterThanOrEqualTo(100));
    });

    test('no template can stop a run', () {
      for (final HarnessTemplate t in harnessTemplates) {
        final Map<String, Object?> json = t.toJson();
        for (final String forbidden in <String>[
          'seconds',
          'minutes',
          'hours',
          'tokens',
          'steps',
          'deadline',
        ]) {
          expect(
            json.keys,
            isNot(contains(forbidden)),
            reason:
                'A template that carries a stop condition is a timer, and a '
                'run that can be ended by one will be.',
          );
        }
      }
    });

    test('breadth never exceeds the angle catalog', () {
      for (final HarnessTemplate t in harnessTemplates) {
        expect(t.angleBreadth, lessThanOrEqualTo(explorationAngles.length));
      }
    });
  });

  group('the domain profiles', () {
    test('number at least six and change what a good direction is', () {
      expect(domainProfiles.length, greaterThanOrEqualTo(6));
      final Set<String> standards = domainProfiles
          .map((DomainProfile p) => p.goodDirection)
          .toSet();
      final Set<String> disqualifiers = domainProfiles
          .map((DomainProfile p) => p.disqualifier)
          .toSet();
      expect(standards.length, domainProfiles.length);
      expect(
        disqualifiers.length,
        domainProfiles.length,
        reason:
            'A profile that only changes vocabulary is a costume, and it is '
            'how a tool that claims to serve any creative project turns out '
            'to be a software tool.',
      );
    });

    test('every essential and favoured reference resolves', () {
      for (final DomainProfile p in domainProfiles) {
        for (final String m in p.essentialModules) {
          expect(() => moduleById(m), returnsNormally);
        }
        for (final String a in p.favouredAngles) {
          expect(() => angleById(a), returnsNormally);
        }
      }
    });
  });

  group('the interview module bank', () {
    test('holds at least twelve modules', () {
      expect(interviewModules.length, greaterThanOrEqualTo(12));
    });

    test('every composed interview produces every part of the brief', () {
      for (final DomainProfile p in domainProfiles) {
        final List<InterviewModule> composed = InterviewComposer.compose(
          profileId: p.id,
        );
        expect(
          InterviewComposer.unservedParts(composed),
          isEmpty,
          reason:
              'An interview for ${p.id} that produces no unknowns leaves the '
              'run with no licence to settle anything on its own, and it '
              'will stall the first time it needs to.',
        );
      }
    });

    test('composition is ordered by the bank, not by the medium', () {
      final List<String> essay = <String>[
        for (final InterviewModule m in InterviewComposer.compose(
          profileId: 'essay',
        ))
          m.id,
      ];
      final List<String> song = <String>[
        for (final InterviewModule m in InterviewComposer.compose(
          profileId: 'song',
        ))
          m.id,
      ];
      final List<String> shared = essay
          .where((String id) => song.contains(id))
          .toList();
      expect(
        shared,
        song.where((String id) => essay.contains(id)).toList(),
        reason:
            'Being interviewed should not feel like a different tool '
            'because of an answer given in the second question.',
      );
    });
  });
}
