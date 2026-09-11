@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:mi_core/mi_core.dart';
import 'package:mi_engine/mi_engine.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// The whole run, driven through a real process boundary.
///
/// Master Prompt learned this the hard way: when the transport is injectable
/// and every test injects a double, the default path — argument composition,
/// the shell decision, closing the child's stdin — has zero executions in the
/// entire suite, and reaches a real machine behind a wall of green. So the
/// council here is the compiled fake binary, spoken to exactly the way the
/// real one is.
void main() {
  late Directory tmp;
  late String fakePath;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('mi-engine-test');
    fakePath = '${tmp.path}/fake_council';
    final ProcessResult r = await Process.run('dart', <String>[
      'compile',
      'exe',
      'tool/fake_council.dart',
      '-o',
      fakePath,
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<ClaudeInstall> install() async {
    final ClaudeCli cli = ClaudeCli(explicitPath: fakePath);
    final ClaudeInstall? found = await cli.locate();
    expect(
      found,
      isNotNull,
      reason: cli.attempts.map((ProbeOutcome o) => o.detail).join('; '),
    );
    return found!;
  }

  test(
    'the binary is found and its capabilities read from its own help',
    () async {
      final ClaudeInstall found = await install();
      expect(found.capabilities.has('--print'), isTrue);
      expect(found.capabilities.supportsValue('--effort', 'high'), isTrue);
      expect(found.capabilities.supportsValue('--effort', 'max'), isFalse);
    },
  );

  test('a turn reaches the process and comes back readable', () async {
    final CliCouncil council = CliCouncil(
      install: await install(),
      workingDirectory: '${tmp.path}/council',
    );
    final CouncilReply reply = await council.ask(
      CouncilTurn(
        agent: const AgentInstance(roleId: 'prospector', round: 1, ordinal: 1),
        purpose: 'propose',
        prompt: 'You are a prospector on a council.',
        conversation: 'propose-1-inversion',
      ),
    );
    expect(reply.text, contains('mi-direction'));
    expect(
      reply.tokensOut,
      greaterThan(0),
      reason: 'stream-json carries usage, and the manifest needs it.',
    );
  });

  test('a whole session runs to dryness through the CLI', () async {
    final Session done = await CouncilRun(
      transport: CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
      ),
      clock: FakeClock(),
    ).deliberate(referenceSession());

    expect(done.directions, isNotEmpty);
    expect(done.ratings, isNotEmpty);
    expect(done.manifest.dryness, isNotNull);
    expect(done.manifest.calls, isNotEmpty);
    expect(
      InvariantSuite.run(done).holds,
      isTrue,
      reason: InvariantSuite.run(done).summary,
    );
  });

  test('two angles finding the same thing leave one direction', () async {
    // Every seat of this fake returns the same proposal, which is the
    // convergence a real council produces constantly.
    final Session done = await CouncilRun(
      transport: CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
      ),
      clock: FakeClock(),
    ).deliberate(referenceSession());

    expect(done.directions, hasLength(1));
    final List<DedupRejection> rejections = <DedupRejection>[
      for (final RoundRecord r in done.rounds) ...r.rejections,
    ];
    expect(rejections, isNotEmpty);
  });

  test('a usage limit arrives as a pause, from stderr', () async {
    // One of the two places a limit can arrive. The other is below.
    final CliCouncil council = CliCouncil(
      install: await install(),
      workingDirectory: '${tmp.path}/council',
      environment: const <String, String>{'MI_FAKE_LIMIT': '1'},
    );
    expect(
      () => council.ask(
        CouncilTurn(
          agent: const AgentInstance(
            roleId: 'prospector',
            round: 1,
            ordinal: 1,
          ),
          purpose: 'propose',
          prompt: 'You are a prospector on a council.',
          conversation: 'propose-1-inversion',
        ),
      ),
      throwsA(isA<CouncilPaused>()),
    );
  });

  CouncilTurn turn([String purpose = 'propose']) => CouncilTurn(
    agent: const AgentInstance(roleId: 'prospector', round: 1, ordinal: 1),
    purpose: purpose,
    prompt: 'You are a prospector on a council.',
    conversation: 'propose-1-inversion',
  );

  test('a usage limit reported on stdout, as the real CLI reports it, is a '
      'pause with the time the provider gave', () async {
    // Under --print the CLI puts its own failures on stdout as a result
    // event with is_error set, and writes nothing to stderr. A transport that
    // read stderr alone ended a real sitting on "The CLI exited with 1: " —
    // nothing after the colon — and recorded a limit that lifts in two hours
    // as a failure that never does.
    final CliCouncil council = CliCouncil(
      install: await install(),
      workingDirectory: '${tmp.path}/council',
      environment: const <String, String>{'MI_FAKE_LIMIT_STDOUT': '1'},
    );
    await expectLater(
      council.ask(turn()),
      throwsA(
        isA<CouncilPaused>()
            .having((CouncilPaused p) => p.kind, 'kind', 'session')
            .having(
              (CouncilPaused p) => p.source,
              'source',
              ResetSource.explicit,
            )
            .having(
              (CouncilPaused p) => p.detail,
              'detail',
              contains('usage limit reached'),
            ),
      ),
      reason:
          'The epoch after the bar is the provider stating when the block '
          'ends, and a resume time it stated is worth more than a guess.',
    );
  });

  test('an exit that said nothing on either stream says so', () async {
    final CliCouncil council = CliCouncil(
      install: await install(),
      workingDirectory: '${tmp.path}/council',
      environment: const <String, String>{'MI_FAKE_MUTE_EXIT': '1'},
    );
    await expectLater(
      council.ask(turn()),
      throwsA(
        isA<CouncilUnavailable>().having(
          (CouncilUnavailable e) => e.detail,
          'detail',
          contains('wrote nothing on either stream'),
        ),
      ),
      reason:
          'An empty reason after a colon reads as the app having forgotten to '
          'say, and gives the client nothing to act on.',
    );
  });

  group('a failure that is not a limit', () {
    test('an expired login fails the sitting rather than pausing it', () async {
      final CliCouncil council = CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
        environment: const <String, String>{'MI_FAKE_AUTH': '1'},
      );
      await expectLater(
        council.ask(turn()),
        throwsA(
          isA<CouncilUnavailable>().having(
            (CouncilUnavailable e) => e.detail,
            'detail',
            contains('not logged in'),
          ),
        ),
        reason:
            'Waiting does not fix a password. A run that waits it out drops '
            'every angle and then records itself as having gone dry.',
      );
    });

    test('any other non-zero exit says what the CLI said', () async {
      final CliCouncil council = CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
        environment: const <String, String>{'MI_FAKE_BROKEN': '1'},
      );
      await expectLater(
        council.ask(turn()),
        throwsA(
          isA<CouncilUnavailable>().having(
            (CouncilUnavailable e) => e.detail,
            'detail',
            contains('not a limit'),
          ),
        ),
      );
    });
  });

  group('a turn that never comes back', () {
    test('is killed and reported, not waited on forever', () async {
      final CliCouncil council = CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
        environment: const <String, String>{'MI_FAKE_HANG': '1'},
        turnTimeout: const Duration(seconds: 2),
      );
      await expectLater(
        council.ask(turn()),
        throwsA(isA<CouncilUnavailable>()),
        reason:
            'A hung child holds its future forever, which on an unattended '
            'run is indistinguishable from a council thinking hard.',
      );
    });
  });

  group('how many turns are in the air at once', () {
    test('never more than the transport was told to allow', () async {
      final Directory live = Directory('${tmp.path}/live')
        ..createSync(recursive: true);
      final CliCouncil council = CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
        maxConcurrent: 2,
        environment: <String, String>{'MI_FAKE_LIVE_DIR': '${live.path}/n'},
      );

      await Future.wait(<Future<CouncilReply>>[
        for (int i = 0; i < 8; i++) council.ask(turn()),
      ]);

      final List<int> peaks = File(
        '${live.path}/peak',
      ).readAsStringSync().trim().split('\n').map(int.parse).toList();
      expect(
        peaks.reduce((int a, int b) => a > b ? a : b),
        lessThanOrEqualTo(2),
        reason:
            'A round at the largest tier would otherwise start some fifty '
            'processes at once, which is itself the commonest way to provoke '
            'the limits this class then has to wait out.',
      );
    });
  });

  group('stopping the transport', () {
    test('refuses every turn after it, at once', () async {
      final CliCouncil council = CliCouncil(
        install: await install(),
        workingDirectory: '${tmp.path}/council',
      );
      council.cancel();
      await expectLater(council.ask(turn()), throwsA(isA<CouncilStopped>()));
    });
  });
}
