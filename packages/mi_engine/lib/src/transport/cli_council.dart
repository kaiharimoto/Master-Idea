import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:mi_core/mi_core.dart';

import '../cli/claude_cli.dart';
import '../cli/limit_reading.dart';
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
    this.maxConcurrent = 4,
    this.turnTimeout = const Duration(minutes: 15),
    this.patterns = LimitReader.defaultPatterns,
    DateTime Function()? now,
  }) : _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final ClaudeInstall install;

  /// A scratch directory of the council's own. Never the client's project.
  final String workingDirectory;

  final String? model;

  /// Extra variables for the child. Kept as a parameter rather than read from
  /// the ambient environment so a test can drive the branch that handles a
  /// provider limit without waiting for a real one.
  final Map<String, String> environment;

  /// How many turns may be in flight at once.
  ///
  /// A round at the largest tier fans out twelve angles, each of which then
  /// judges its own directions concurrently — some fifty `claude` processes on
  /// a laptop, which is itself the commonest way to provoke the limits this
  /// class then has to wait out. **Not a stop condition**: nothing here can end
  /// a round or a run, it only decides how many turns are in the air at once,
  /// and breadth and the dryness rule are untouched by it.
  final int maxConcurrent;

  /// How long one turn may take before the process is killed.
  ///
  /// A hung child otherwise holds its future forever with nothing to break it,
  /// which on an unattended run is indistinguishable from a council that is
  /// thinking hard.
  final Duration turnTimeout;

  /// The wordings a limit arrives in. Data, so a change to them is not a
  /// release.
  final LimitPatterns patterns;

  final DateTime Function() _now;

  /// When this sitting's first turn ran, which is what a five-hour block is
  /// measured from when the provider will not say.
  DateTime? _blockStartedAt;

  int _live = 0;
  final Queue<Completer<void>> _queue = Queue<Completer<void>>();
  final Set<Process> _running = <Process>{};
  bool _stopped = false;

  TurnPlan? _plan;

  TurnPlan planFor() => _plan ??= TurnPlanBuilder.build(
    executable: install.path,
    capabilities: install.capabilities,
    workingDirectory: workingDirectory,
    throughShell: install.throughShell,
    model: model,
  );

  /// What this build of the CLI could not do, and what was used instead.
  ///
  /// Surfaced rather than kept, because the commonest degradation — a build
  /// without `stream-json` — costs the manifest its token figures for the
  /// whole run, and a manifest that quietly reports nothing spent is not
  /// distinguishable from one that measured nothing.
  List<String> get notes => planFor().notes;

  /// Stop this transport. Every turn in flight is killed and every turn after
  /// it refused, so a run driven by this ends at once rather than at the end
  /// of whatever it happened to be doing.
  void cancel() {
    _stopped = true;
    for (final Process p in _running.toList()) {
      p.kill(ProcessSignal.sigterm);
    }
    _running.clear();
    while (_queue.isNotEmpty) {
      final Completer<void> c = _queue.removeFirst();
      if (!c.isCompleted) c.complete();
    }
  }

  @override
  Future<CouncilReply> ask(CouncilTurn turn) async {
    if (_stopped) throw CouncilStopped(_now());
    await _acquire();
    try {
      if (_stopped) throw CouncilStopped(_now());
      return await _run(turn);
    } finally {
      _release();
    }
  }

  Future<void> _acquire() async {
    if (_live < maxConcurrent) {
      _live++;
      return;
    }
    final Completer<void> waiting = Completer<void>();
    _queue.add(waiting);
    await waiting.future;
    _live++;
  }

  void _release() {
    _live--;
    if (_queue.isNotEmpty && _live < maxConcurrent) {
      final Completer<void> next = _queue.removeFirst();
      if (!next.isCompleted) next.complete();
    }
  }

  Future<CouncilReply> _run(CouncilTurn turn) async {
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
    _running.add(process);
    _blockStartedAt ??= _now();

    // The prompt goes down stdin rather than on the command line: a propose
    // turn runs to several thousand characters, and Windows refuses a command
    // line past about thirty-two thousand — through a .cmd, far less.
    // Wrapped because a child that has already died makes this a broken pipe,
    // and the useful account of what went wrong is on its stderr and in its
    // exit code — both of which are read below. An IOException thrown from
    // here would replace that account with a plumbing error.
    try {
      process.stdin.write(turn.prompt);
    } on Object {
      // Deliberately ignored; the exit code below says what happened.
    }
    // `Process.start` does not close the child's stdin. Without this the CLI
    // waits for more piped input on every single turn.
    unawaited(process.stdin.close().catchError((Object _) {}));

    final StringBuffer out = StringBuffer();
    final StringBuffer err = StringBuffer();
    final Future<void> stdoutDone = process.stdout
        .transform(utf8.decoder)
        .forEach(out.write);
    final Future<void> stderrDone = process.stderr
        .transform(utf8.decoder)
        .forEach(err.write);

    bool timedOut = false;
    final Timer killer = Timer(turnTimeout, () {
      timedOut = true;
      process.kill(ProcessSignal.sigkill);
    });

    int code;
    try {
      await Future.wait(<Future<void>>[stdoutDone, stderrDone]);
      code = await process.exitCode;
    } finally {
      killer.cancel();
      _running.remove(process);
    }

    if (_stopped) throw CouncilStopped(_now());
    if (timedOut) {
      throw CouncilUnavailable(
        'The turn was still running after ${turnTimeout.inMinutes} minutes '
        'and was killed. A hung call is not a council thinking.',
      );
    }

    // A usage limit is reported on **stderr and nowhere else**. `Error.message`
    // is non-enumerable and the CLI serialises with a plain JSON.stringify, so
    // limit text can never appear in the stdout JSON stream — a detector that
    // greps stdout matches nothing, forever, and presents as a hang.
    final LimitReading reading = LimitReader.read(
      err.toString(),
      now: _now(),
      blockStartedAt: _blockStartedAt,
      patterns: patterns,
    );
    if (reading.kind.liftsByWaiting) {
      throw CouncilPaused(
        reading.kind.name,
        reading.detail,
        reading.until!,
        source: reading.source,
      );
    }

    if (code != 0) {
      // Everything else fails the sitting where it stands. None of these lift
      // by waiting, and a run that waits them out loses every search and then
      // records the provider's silence as the council's.
      throw CouncilUnavailable(switch (reading.kind) {
        FailureKind.auth =>
          'The Claude CLI is not logged in, or its token has expired. '
              '${reading.detail}',
        FailureKind.overage =>
          'The account has no credit left for this. Waiting will not lift it. '
              '${reading.detail}',
        _ => 'The CLI exited with $code: ${reading.detail}',
      });
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
}
