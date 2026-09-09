import 'package:mi_engine/mi_engine.dart';
import 'package:test/test.dart';

const String help = '''
Usage: claude [options] [prompt]
  -p, --print                      Print response and exit
      --output-format <format>     Output format (choices: "text", "json", "stream-json")
      --verbose                    Emit all events
      --permission-mode <mode>     Permission mode (choices: "default", "acceptEdits", "bypassPermissions")
      --model <model>              Model alias or full name
      --effort <level>             Reasoning effort (choices: "low", "medium", "high")
      --resume <id>                Resume a session
''';

CliCapabilities caps([String text = help]) =>
    CliCapabilities.parse(text, version: '2.1.42');

TurnPlan planWith(CliCapabilities c, {String? model}) => TurnPlanBuilder.build(
  executable: '/usr/local/bin/claude',
  capabilities: c,
  workingDirectory: '/tmp/council',
  model: model,
);

void main() {
  group('what the build says it can do', () {
    test('flags and their enumerated values are read from help', () {
      final CliCapabilities c = caps();
      expect(c.has('--print'), isTrue);
      expect(c.supportsValue('--effort', 'high'), isTrue);
      expect(
        c.supportsValue('--effort', 'max'),
        isFalse,
        reason:
            'A documented level the build in front of you does not accept '
            'fails at run time, on every turn, unless the probe catches it.',
      );
    });

    test('a flag that enumerates nothing accepts anything', () {
      expect(
        caps().supportsValue('--model', 'opus'),
        isTrue,
        reason:
            '--model takes an alias or a full dated name and lists neither, '
            'so refusing an unlisted value would make valid models unusable.',
      );
    });
  });

  group('the turn plan', () {
    test('refuses to build without --print', () {
      expect(
        () => planWith(caps('Usage: claude\n  --output-format <f>\n')),
        throwsA(isA<TurnPlanError>()),
        reason:
            'Without --print the CLI opens an interactive session and simply '
            'hangs, which is worse than refusing.',
      );
    });

    test('asks for --verbose whenever it asks for stream-json', () {
      final List<String> args = planWith(caps()).arguments;
      expect(
        args,
        containsAllInOrder(<String>['--output-format', 'stream-json']),
      );
      expect(
        args,
        contains('--verbose'),
        reason:
            'stream-json writes nothing at all without it, which is '
            'indistinguishable from a hang.',
      );
    });

    test('falls back to text, and says what was lost', () {
      final TurnPlan plan = planWith(
        caps(
          'Usage: claude\n  -p, --print\n  --output-format <f> (choices: "text")\n',
        ),
      );
      expect(
        plan.arguments,
        containsAllInOrder(<String>['--output-format', 'text']),
      );
      expect(plan.notes.join(), contains('token usage'));
    });

    test('never asks for anything but the default permission mode', () {
      final List<String> args = planWith(caps()).arguments;
      expect(
        args,
        containsAllInOrder(<String>['--permission-mode', 'default']),
      );
      expect(
        args,
        isNot(contains('bypassPermissions')),
        reason:
            'A seat arguing about what an idea could be needs no tools at '
            'all.',
      );
      expect(args, isNot(contains('--dangerously-skip-permissions')));
    });

    test('opens no session and resumes nothing', () {
      final List<String> args = planWith(caps()).arguments;
      expect(args, isNot(contains('--resume')));
      expect(
        args,
        isNot(contains('--session-id')),
        reason:
            'Seats sharing a conversation share context, and an assessor '
            'that inherits the prospector\'s case is rating the advocacy.',
      );
    });

    test('degrades effort downward, never upward', () {
      final TurnPlan plan = TurnPlanBuilder.build(
        executable: 'claude',
        capabilities: caps(
          'Usage: claude\n  -p, --print\n  --effort <l> (choices: "low")\n',
        ),
        workingDirectory: '/tmp/council',
        effortPreference: <String>['high', 'medium', 'low'],
      );
      expect(plan.arguments, containsAllInOrder(<String>['--effort', 'low']));
      expect(plan.notes.join(), contains('reduced'));
    });

    test('sends no --model at all when none is chosen', () {
      expect(planWith(caps()).arguments, isNot(contains('--model')));
      expect(
        planWith(caps(), model: 'opus').arguments,
        containsAllInOrder(<String>['--model', 'opus']),
      );
    });
  });
}
