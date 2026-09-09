import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

Future<Session> assembled() async {
  final ScriptedCouncil council = ScriptedCouncil();
  final CouncilRun run = CouncilRun(transport: council, clock: FakeClock());
  final Session ran = await run.deliberate(referenceSession());
  final List<String> chosen = <String>[
    ran.directions[0].id,
    ran.directions[2].id,
  ];
  final Integration? integration = await run.integrate(ran, chosen);
  return ran.copyWith(selection: chosen, integration: integration);
}

void main() {
  group('the pitch', () {
    test('carries only what the client selected', () async {
      final Session s = await assembled();
      final String pitch = PitchComposer.compose(s);
      for (final Direction d in s.directions) {
        if (s.selection.contains(d.id)) {
          expect(pitch, contains(d.title));
        } else {
          expect(
            pitch,
            isNot(contains(d.title)),
            reason:
                'The council never decides what ships. A direction the '
                'client left behind must not appear here in any form.',
          );
        }
      }
    });

    test(
      'inherits the computed integration rather than restating each case',
      () async {
        final Session s = await assembled();
        final String pitch = PitchComposer.compose(s);
        expect(pitch, contains(s.integration!.becomes));
        expect(pitch, contains('How they hold together'));
      },
    );

    test('names the conflicts the client chose anyway', () async {
      final Session s = await assembled();
      final String pitch = PitchComposer.compose(s);
      expect(pitch, contains('conflict'));
    });

    test('carries the revisit points that bear on the selection', () async {
      final Session s = await assembled();
      final String pitch = PitchComposer.compose(s);
      expect(pitch, contains('assumed'));
      expect(pitch, contains(s.assumptions.first.made));
    });

    test('reads as a launch document, not a summary of the session', () async {
      final String pitch = PitchComposer.compose(await assembled());
      expect(
        pitch,
        isNot(contains('round ')),
        reason:
            'Rounds, angles and seats are the deliberation. The launch '
            'document is for whoever builds the thing.',
      );
      expect(pitch, isNot(contains('mi-rating')));
    });

    test('would work in front of a model that is not Claude', () async {
      final String pitch = PitchComposer.compose(await assembled());
      expect(
        PitchPortability.tells(pitch),
        isEmpty,
        reason:
            'The pitch is the one artifact that leaves this pair of tools '
            'entirely.',
      );
    });

    test(
      'carries a machine block Master Prompt can open a mission from',
      () async {
        final Session s = await assembled();
        final String pitch = PitchComposer.compose(s);
        final ParsedReply block = _readPitchBlock(pitch);
        expect(block.fields['v'], '1');
        expect(block.fields['session'], s.id);
        expect(block.fields['medium'], s.interview.profileId);
        expect(block.fields['tier'], s.interview.verdict.templateId);
        expect(block.fields['mission'], isNotEmpty);
        expect(block.fields['audience'], isNotEmpty);
        expect(
          block.fields['mission'],
          isNot(contains('\n')),
          reason:
              'Line-oriented on purpose: a document cut off by a paste limit '
              'loses one field here where JSON would lose everything.',
        );
      },
    );

    test('a portability tell is actually detected', () {
      expect(
        PitchPortability.isPortable(
          'Start by reading CLAUDE.md, then run with --permission-mode '
          'bypassPermissions.',
        ),
        isFalse,
        reason:
            'The check has to fail on something, or it is a habit rather than '
            'a test.',
      );
    });
  });
}

/// The `mi-pitch` block, read the way Master Prompt would read it.
_PitchBlock _readPitchBlock(String pitch) {
  final List<String> lines = pitch.split('\n');
  final int start = lines.indexWhere((String l) => l.trim() == '```mi-pitch');
  expect(start, greaterThanOrEqualTo(0));
  final Map<String, String> fields = <String, String>{};
  for (final String line in lines.skip(start + 1)) {
    if (line.trim() == '```') break;
    final int eq = line.indexOf('=');
    if (eq > 0) fields[line.substring(0, eq)] = line.substring(eq + 1);
  }
  return _PitchBlock(fields);
}

class _PitchBlock {
  const _PitchBlock(this.fields);
  final Map<String, String> fields;
}

typedef ParsedReply = _PitchBlock;
