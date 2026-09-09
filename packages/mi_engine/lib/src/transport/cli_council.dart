import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mi_core/mi_core.dart';

import '../cli/claude_cli.dart';
import '../cli/turn_plan.dart';

/// The council, reached through the Claude Code CLI.
///
/// One process per turn, in a directory of its own, with no session and no
/// resume. That is the shape the independence invariant demands: two seats
/// sharing a conversation share context, and an assessor that inherits a
/// prospector's case is rating the advocacy however carefully the code avoids
/// passing it.
///
/// The working directory matters for the reason Master Prompt found: a
/// `CLAUDE.md` in the project the idea is *about* would otherwise join the
/// deliberation uninvited, and the council would start arguing about a
/// codebase instead of an idea.
class CliCouncil implements CouncilTransport {
  CliCouncil({
    required this.install,
    required this.workingDirectory,
    this.model,
    this.environment = const <String, String>{},
    this.limitPauseFor = const Duration(minutes: 20),
  });

  final ClaudeInstall install;

  /// A scratch directory of the council's own. Never the client's project.
  final String workingDirectory;

  final String? model;

  /// Extra variables for the child. Kept as a parameter rather than read from
  /// the ambient environment so a test can drive the branch that handles a
  /// provider limit without waiting for a real one.
  final Map<String, String> environment;

  /// How long to wait when the provider reports a limit without saying when it
  /// lifts. A guess, and recorded as one in the manifest — but a guess that
  /// waits is right, because the alternative is recording a limit as silence
  /// and a limit recorded as silence ends a run that had not finished.
  final Duration limitPauseFor;

  TurnPlan planFor() => TurnPlanBuilder.build(
    executable: install.path,
    capabilities: install.capabilities,
    workingDirectory: workingDirectory,
    throughShell: install.throughShell,
    model: model,
  );

  @override
  Future<CouncilReply> ask(CouncilTurn turn) async {
    final TurnPlan plan = planFor();
    final Directory dir = Directory(workingDirectory);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final Process process = await Process.start(
      plan.executable,
      plan.arguments,
      workingDirectory: plan.workingDirectory,
      runInShell: plan.throughShell,
      environment: environment.isEmpty ? null : environment,
      includeParentEnvironment: true,
    );

    // The prompt goes down stdin rather than on the command line: a propose
    // turn runs to several thousand characters, and Windows refuses a command
    // line past about thirty-two thousand — through a .cmd, far less.
    process.stdin.write(turn.prompt);
    // `Process.start` does not close the child's stdin. Without this the CLI
    // waits for more piped input on every single turn.
    unawaited(process.stdin.close());

    final StringBuffer out = StringBuffer();
    final StringBuffer err = StringBuffer();
    final Future<void> stdoutDone = process.stdout
        .transform(utf8.decoder)
        .forEach(out.write);
    final Future<void> stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(err.write);
    await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
    final int code = await process.exitCode;

    // A usage limit is reported on **stderr and nowhere else**. `Error.message`
    // is non-enumerable and the CLI serialises with a plain JSON.stringify, so
    // limit text can never appear in the stdout JSON stream — a detector that
    // greps stdout matches nothing, forever, and presents as a hang.
    final DateTime? until = _limitUntil(err.toString());
    if (until != null) {
      throw CouncilPaused('session', err.toString().trim(), until);
    }

    if (code != 0) {
      throw CouncilPaused(
        'rate',
        'The CLI exited with $code: ${err.toString().trim()}',
        DateTime.now().toUtc().add(limitPauseFor),
      );
    }

    return _read(out.toString());
  }

  /// Pull the assistant's text and its usage out of whatever the build wrote.
  static CouncilReply _read(String stdout) {
    final StringBuffer text = StringBuffer();
    int tokensIn = 0;
    int tokensOut = 0;
    bool sawJson = false;

    for (final String line in stdout.split('\n')) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('{')) continue;
      Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, Object?>) continue;
      sawJson = true;
      final Object? usage = decoded['usage'];
      if (usage is Map<String, Object?>) {
        tokensIn += (usage['input_tokens'] as num?)?.toInt() ?? 0;
        tokensOut += (usage['output_tokens'] as num?)?.toInt() ?? 0;
      }
      final Object? message = decoded['message'];
      if (message is Map<String, Object?>) {
        final Object? content = message['content'];
        if (content is List<Object?>) {
          for (final Object? part in content) {
            if (part is Map<String, Object?> && part['type'] == 'text') {
              text.writeln('${part['text']}');
            }
          }
        }
      }
      final Object? result = decoded['result'];
      if (result is String && decoded['type'] == 'result') {
        text.writeln(result);
      }
    }

    // A build with no stream-json writes plain text, and a turn is still a
    // turn. Falling back rather than refusing is what keeps an older CLI
    // usable at the cost of usage figures the manifest records as zero.
    return CouncilReply(
      text: sawJson ? text.toString() : stdout,
      tokensIn: tokensIn,
      tokensOut: tokensOut,
    );
  }

  /// When the provider says the limit lifts, if it says.
  static DateTime? _limitUntil(String stderr) {
    final String s = stderr.toLowerCase();
    final bool isLimit =
        s.contains('usage limit') ||
        s.contains('rate limit') ||
        s.contains('limit reached') ||
        s.contains('resets at');
    if (!isLimit) return null;

    // `resets at 3pm`, `retry after 900 seconds`, or an epoch. Anything the
    // wording does not give is treated as unknown, and the caller waits its
    // default rather than guessing short.
    final RegExpMatch? epoch = RegExp(r'\b(1[6-9]\d{8})\b').firstMatch(s);
    if (epoch != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        int.parse(epoch.group(1)!) * 1000,
        isUtc: true,
      );
    }
    final RegExpMatch? seconds = RegExp(
      r'(?:retry after|in)\s+(\d+)\s*second',
    ).firstMatch(s);
    if (seconds != null) {
      return DateTime.now().toUtc().add(
        Duration(seconds: int.parse(seconds.group(1)!)),
      );
    }
    return DateTime.now().toUtc().add(const Duration(minutes: 20));
  }
}
