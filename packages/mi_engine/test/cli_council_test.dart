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
    // The real CLI can only report a limit on stderr: Error.message is
    // non-enumerable and the CLI serialises with a plain JSON.stringify, so
    // limit text never reaches the stdout JSON stream. A detector that greps
    // stdout matches nothing, forever, and presents as a hang.
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
}
