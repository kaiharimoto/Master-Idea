// A stand-in for the `claude` binary, for tests.
//
// It refuses what the real one refuses — a missing `--print`, an unknown flag,
// stream-json without `--verbose` — with the real binary's behaviour, because a
// double that accepts everything proves only that the code runs. It also waits
// for stdin to reach EOF and complains if it does not, so forgetting to close
// the child's stdin fails on the runner rather than costing three seconds of
// every turn on someone's desk.
//
// `MI_FAKE_LIMIT=1` makes it report a usage limit on stderr and nothing on
// stdout, which is what the real CLI does: `Error.message` is non-enumerable
// and the CLI serialises with a plain JSON.stringify, so limit text can never
// reach the stdout JSON stream.
import 'dart:convert';
import 'dart:io';

const String version = '2.1.42 (fake council)';

const String help = '''
Usage: claude [options] [prompt]

Options:
  -p, --print                      Print response and exit
      --output-format <format>     Output format (choices: "text", "json", "stream-json")
      --verbose                    Emit all events; required by stream-json
      --permission-mode <mode>     Permission mode (choices: "default", "acceptEdits", "bypassPermissions")
      --model <model>              Model alias or full name
      --effort <level>             Reasoning effort (choices: "low", "medium", "high")
      --session-id <uuid>          Use a specific session id
      --resume <id>                Resume a session
      --fork-session               Fork the resumed session
  -h, --help                       Show help
      --version                    Show version
''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.write(help);
    exit(0);
  }
  if (args.contains('--version')) {
    stdout.writeln(version);
    exit(0);
  }

  const Set<String> known = <String>{
    '--print',
    '-p',
    '--output-format',
    '--verbose',
    '--permission-mode',
    '--model',
    '--effort',
    '--session-id',
    '--resume',
    '--fork-session',
  };
  String? format;
  for (int i = 0; i < args.length; i++) {
    final String a = args[i];
    if (!a.startsWith('-')) continue;
    if (!known.contains(a)) {
      stderr.writeln("error: unknown option '$a'");
      exit(1);
    }
    if (a == '--output-format') {
      format = i + 1 < args.length ? args[i + 1] : null;
    }
    if (a == '--permission-mode') {
      final String mode = i + 1 < args.length ? args[i + 1] : '';
      if (!<String>[
        'default',
        'acceptEdits',
        'bypassPermissions',
      ].contains(mode)) {
        stderr.writeln("error: invalid permission mode '$mode'");
        exit(1);
      }
    }
    if (a == '--effort') {
      final String level = i + 1 < args.length ? args[i + 1] : '';
      if (!<String>['low', 'medium', 'high'].contains(level)) {
        stderr.writeln("error: invalid effort '$level'");
        exit(1);
      }
    }
  }

  if (!args.contains('--print') && !args.contains('-p')) {
    stderr.writeln('error: interactive mode is not available here');
    exit(1);
  }

  // The prompt arrives on stdin. If nobody closes it, the real CLI sits
  // waiting; say so loudly rather than hanging the suite.
  final String prompt = await stdin
      .transform(utf8.decoder)
      .join()
      .timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          // Failing rather than warning. `Process.start` does not close the
          // child's stdin, so a caller that forgets makes the real CLI wait
          // for piped input on every single turn — three seconds a turn, six
          // hundred turns, and nobody watching. That must fail on the runner.
          stderr.writeln(
            'error: stdin never reached EOF — the caller did not close it',
          );
          exit(2);
        },
      );

  if (Platform.environment['MI_FAKE_LIMIT'] == '1') {
    stderr.writeln(
      'Claude usage limit reached. Your limit resets at 3pm. retry after 5 '
      'seconds',
    );
    exit(1);
  }

  final String body = _answer(prompt);

  if (format == 'stream-json') {
    if (!args.contains('--verbose')) {
      // Verified against the real binary: stream-json writes nothing at all
      // without --verbose, which presents as a hang.
      exit(0);
    }
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'type': 'assistant',
        'message': <String, Object?>{
          'content': <Object?>[
            <String, Object?>{'type': 'text', 'text': body},
          ],
        },
        'usage': <String, Object?>{
          'input_tokens': prompt.length ~/ 4,
          'output_tokens': body.length ~/ 4,
        },
      }),
    );
    stdout.writeln(
      jsonEncode(<String, Object?>{'type': 'result', 'subtype': 'success'}),
    );
  } else {
    stdout.write(body);
  }
  exit(0);
}

/// Answer in the council's own grammar, keyed off what the prompt asked for.
String _answer(String prompt) {
  if (prompt.contains('You are an assessor')) {
    final List<String> rungs = _rungs(prompt);
    return 'mi-rating\n'
        'verdict=${rungs[rungs.length ~/ 2]}\n'
        'because=Judged on what is written, with no idea who wrote it.\n'
        'end';
  }
  if (prompt.contains('You are the dissenting seat')) {
    return 'mi-none';
  }
  if (prompt.contains('You are a challenger')) {
    return 'mi-challenge\n'
        'attack=The mechanism needs an audience that does not exist yet.\n'
        'fatal=no\n'
        'end';
  }
  if (prompt.contains('You are the cartographer')) {
    return 'mi-territory\n'
        'id=t-fake-explored\n'
        'name=Ground already walked\n'
        'description=What the council entered this round.\n'
        'status=explored\n'
        'end\n'
        'mi-territory\n'
        'id=t-fake-dropped\n'
        'name=Ground deliberately left\n'
        'description=A territory the council refused to enter.\n'
        'status=dropped\n'
        'reason=The client put it out of bounds in the interview.\n'
        'end\n'
        'mi-territory\n'
        'id=t-fake-gap\n'
        'name=Ground nobody has entered\n'
        'description=Still open.\n'
        'status=gap\n'
        'end';
  }
  if (prompt.contains('You are the integrator')) {
    return 'mi-integration\n'
        'becomes=One proceeding rather than a pile of options.\n'
        'end';
  }
  // A prospector. Answer once and then go quiet, so a run driven by this
  // binary reaches dryness instead of running forever.
  if (prompt.contains('OPEN GAPS IN THE MAP')) return 'mi-none';
  return 'mi-direction\n'
      'cluster=What the thing is for\n'
      'ambition=reckless\n'
      'title=Give the archive away and charge for the index\n'
      'statement=Publish every case file and sell only the index that makes '
      'one findable.\n'
      'mechanism=The archive is static and mirrored; the index is regenerated '
      'per client against their own question.\n'
      'trace-answer=raw-idea\n'
      'quote=the idea as the client first said it\n'
      'end';
}

List<String> _rungs(String prompt) {
  final List<String> lines = prompt.split('\n');
  final int i = lines.indexWhere(
    (String l) => l.trim() == 'ANSWER WITH EXACTLY ONE OF',
  );
  if (i < 0 || i + 1 >= lines.length) {
    stderr.writeln('error: the rating prompt carried no vocabulary');
    exit(1);
  }
  return lines[i + 1].split(',').map((String s) => s.trim()).toList();
}
