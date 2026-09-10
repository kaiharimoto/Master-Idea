// The headless entry point.
//
// The engine is driven from the command line before any interface exists,
// because the three hard invariants become unfixable once one sits on top of
// them — and because a session must be inspectable, checkable and renderable
// by someone who has only the files, a year from now, with no app installed.
import 'dart:convert';
import 'dart:io';

import 'package:mi_core/mi_core.dart';
import 'package:mi_engine/mi_engine.dart';

const String usage = '''
mi — Master Idea, headless

  mi new <sessions-dir> <interview.json>
      Open a session from a completed interview record. The gate is checked
      here: a run does not open without a confirmed brief and declared
      unknowns.

  mi run <sessions-dir> <id> [--claude <path>] [--model <name>]
      Deliberate to dryness through the Claude CLI. The run ends when two
      consecutive rounds at the same breadth return nothing new, and for no
      other reason.

  mi check <sessions-dir> [<id>]
      Run the invariant self-test over one stored session, or all of them.
      Exits non-zero on any violation.

  mi render <sessions-dir> <id> dossier|ledger|pitch
      Render from the stored files alone, with no council and no network.

  mi select <sessions-dir> <id> <direction-id>...
      Record what the client chose, compute the integration across that set,
      and write the pitch.

  mi rm <sessions-dir> <id>
      Delete a stored session and everything in it.

  mi list <sessions-dir>

Common options:
  --claude <path>   Use this binary rather than asking the operating system.
  --model <name>    Send this model to every turn.
''';

Future<void> main(List<String> argv) async {
  // The dispatch returns the exit code rather than setting it, because a
  // return value from `main` is ignored: a command that "failed" with a
  // returned 1 and a zero exit status is a check that always passes.
  exitCode = await _dispatch(argv);
}

Future<int> _dispatch(List<String> argv) async {
  if (argv.isEmpty) {
    stdout.write(usage);
    return 64;
  }
  final String command = argv.first;
  final List<String> rest = argv.skip(1).toList();

  try {
    switch (command) {
      case 'new':
        return _new(rest);
      case 'run':
        return await _run(rest);
      case 'check':
        return _check(rest);
      case 'render':
        return _render(rest);
      case 'select':
        return await _select(rest);
      case 'rm':
        return _rm(rest);
      case 'list':
        return _list(rest);
      default:
        stdout.write(usage);
        return 64;
    }
  } on StateError catch (e) {
    stderr.writeln(e.message);
    return 70;
  } on FormatException catch (e) {
    // A truncated or hand-edited file. Named for what it is rather than
    // reaching the terminal as an uncaught crash with a Dart stack trace,
    // which tells the person holding the files nothing they can act on.
    stderr.writeln('A stored file could not be read: ${e.message}');
    return 65;
  } on TypeError catch (e) {
    stderr.writeln('A stored file is not the shape this build expects: $e');
    return 65;
  }
}

SessionStore _store(String dir) => SessionStore(Directory(dir));

int _new(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('mi new <sessions-dir> <interview.json>');
    return 64;
  }
  final SessionStore store = _store(args[0]);
  final InterviewRecord interview = InterviewRecord.fromJson(
    jsonDecode(File(args[1]).readAsStringSync())! as Map<String, Object?>,
  );

  final List<GateRefusal> refusals = InterviewGate.refusals(interview);
  if (refusals.isNotEmpty) {
    stderr.writeln('This interview cannot open a run:');
    for (final GateRefusal r in refusals) {
      stderr.writeln('  - ${r.reason}');
    }
    return 65;
  }

  final String id = store.mintId();
  final String title = SessionTitle.from(interview.brief.restatement);
  final Session session = Session(
    id: id,
    taskId: SessionTitle.slug(title),
    title: title,
    createdAt: DateTime.now().toUtc(),
    interview: interview,
    manifest: RunManifest(
      sessionId: id,
      templateId: interview.verdict.templateId,
      tier: interview.verdict.template.tier,
      transport: 'cli',
      startedAt: DateTime.now().toUtc(),
    ),
  );
  store.write(session);
  stdout.writeln('Opened $id — ${interview.verdict.template.name}.');
  stdout.writeln(interview.verdict.template.expectation);
  return 0;
}

Future<int> _run(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'mi run <sessions-dir> <id> [--claude <path>] [--model <n>]',
    );
    return 64;
  }
  final SessionStore store = _store(args[0]);
  final Session session = store.read(args[1]);

  final ClaudeCli cli = ClaudeCli(
    explicitPath: _option(args, '--claude'),
    onWindows: Platform.isWindows,
  );
  final ClaudeInstall? install = await cli.locate();
  if (install == null) {
    stderr.writeln('No Claude CLI answered. What was tried:');
    for (final ProbeOutcome o in cli.attempts) {
      stderr.writeln('  ${o.path}: ${o.detail}');
    }
    return 69;
  }

  final Directory scratch = Directory(
    '${store.root.path}/${session.id}/.council',
  )..createSync(recursive: true);

  if (!store.lock(session.id, 'mi run pid $pid')) {
    stderr.writeln(
      'Session ${session.id} is already being run by ${store.lockedBy(session.id)}. '
      'Two writers hold the whole session in memory and write it out entire, '
      'so the second to finish would discard the first\'s rounds.',
    );
    return 73;
  }

  final CliCouncil council = CliCouncil(
    install: install,
    // A directory of the council's own. A CLAUDE.md in the project the idea
    // is about must not join the deliberation uninvited.
    workingDirectory: scratch.path,
    model: _option(args, '--model'),
  );
  for (final String note in council.notes) {
    stdout.writeln('note: $note');
  }

  final CouncilRun run = CouncilRun(
    transport: council,
    onEvent: (RunEvent e) => stdout.writeln(e),
    // Every barrier, not just the end. A run killed at hour four should lose
    // the round it was in and nothing else.
    onBarrier: (Session s) async => store.write(s),
  );

  final Session done;
  try {
    done = await run.deliberate(
      session.copyWith(manifest: session.manifest.onTransport('cli')),
    );
  } on CouncilUnavailable catch (e) {
    final Session? sofar = run.sessionSoFar;
    if (sofar != null) store.write(sofar);
    stderr.writeln('$e');
    stderr.writeln(
      'The rounds already closed are stored. Fix this and run the same '
      'command again — the sitting resumes from round '
      '${(sofar?.rounds.length ?? 0) + 1}.',
    );
    return 75;
  } on CouncilStopped catch (e) {
    final Session? sofar = run.sessionSoFar;
    if (sofar != null) store.write(sofar);
    stdout.writeln('$e');
    return 0;
  } finally {
    store.unlock(session.id);
  }

  final DrynessDecision dry = done.manifest.dryness!;
  stdout.writeln(
    'Dry after rounds ${dry.firstRound} and ${dry.secondRound}: '
    '${done.directions.length} directions, ${done.ratings.length} verdicts, '
    '${done.manifest.councilTime.inMinutes} minutes of council time.',
  );
  if (dry.wentDryBelowFloor) {
    stdout.writeln(
      'It went dry below the ${dry.floorAtTier} this tier expects. Re-tier the '
      'session downward rather than running it on — a direction added to reach '
      'a number is a direction nobody asked for.',
    );
  }
  return 0;
}

int _check(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('mi check <sessions-dir> [<id>]');
    return 64;
  }
  final SessionStore store = _store(args[0]);
  final List<String> ids = args.length > 1
      ? <String>[args[1]]
      : store.listIds();
  if (ids.isEmpty) {
    stderr.writeln('No stored sessions in ${args[0]}.');
    return 66;
  }
  bool ok = true;
  for (final String id in ids) {
    final InvariantReport report = InvariantSuite.run(store.read(id));
    stdout.writeln(report.summary.trimRight());
    ok = ok && report.holds;
  }
  return ok ? 0 : 1;
}

int _render(List<String> args) {
  if (args.length < 3) {
    stderr.writeln('mi render <sessions-dir> <id> dossier|ledger|pitch');
    return 64;
  }
  final Session s = _store(args[0]).read(args[1]);
  switch (args[2]) {
    case 'dossier':
      stdout.write(DossierRenderer.render(s).toText());
    case 'ledger':
      stdout.write(LedgerRenderer.render(s).toText());
    case 'pitch':
      if (s.pitch.isEmpty) {
        stderr.writeln(
          'Nothing has been selected yet, and the council never decides what '
          'ships. Run `mi select` first.',
        );
        return 65;
      }
      stdout.write(s.pitch);
    default:
      stderr.writeln('Unknown view "${args[2]}".');
      return 64;
  }
  return 0;
}

Future<int> _select(List<String> args) async {
  if (args.length < 3) {
    stderr.writeln('mi select <sessions-dir> <id> <direction-id>...');
    return 64;
  }
  final SessionStore store = _store(args[0]);
  final Session session = store.read(args[1]);
  final List<String> chosen = <String>[
    for (final String a in args.skip(2))
      if (a.startsWith('d-')) a,
  ];
  for (final String id in chosen) {
    if (session.directionById(id) == null) {
      stderr.writeln('No direction "$id" in this session.');
      return 65;
    }
  }

  final ClaudeCli cli = ClaudeCli(
    explicitPath: _option(args, '--claude'),
    onWindows: Platform.isWindows,
  );
  final ClaudeInstall? install = await cli.locate();
  Integration? integration;
  if (install != null) {
    integration = await CouncilRun(
      transport: CliCouncil(
        install: install,
        workingDirectory: '${store.root.path}/${session.id}/.council',
      ),
    ).integrate(session, chosen);
  } else {
    stderr.writeln(
      'No Claude CLI answered, so the selection is recorded without an '
      'integration. The pitch will carry the directions and say nothing about '
      'what they become together, which is the part only the council can '
      'compute.',
    );
  }

  final Session assembled = session.copyWith(
    selection: chosen,
    integration: integration,
    // An integration computed for a selection nobody has any more is worse
    // than none: it reads as current.
    dropIntegration: integration == null,
  );
  final Session withPitch = assembled.copyWith(
    pitch: PitchComposer.compose(assembled),
  );

  // Checked before it is written, not after. A pitch that fails this and is
  // on disk anyway is a file somebody will send.
  final List<String> tells = PitchPortability.tells(withPitch.pitch);
  if (tells.isNotEmpty) {
    stderr.writeln('This pitch is not portable. Found: ${tells.join(', ')}');
    stderr.writeln('Nothing was written.');
    return 65;
  }

  store.write(withPitch);
  stdout.writeln('Wrote ${store.root.path}/${session.id}/pitch.md');
  return 0;
}

int _rm(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('mi rm <sessions-dir> <id>');
    return 64;
  }
  final SessionStore store = _store(args[0]);
  if (!store.exists(args[1])) {
    stderr.writeln('No session "${args[1]}" in ${args[0]}.');
    return 66;
  }
  // Read for the title, but never let an unreadable session refuse to be
  // deleted: an unopenable session is the one a person most wants rid of.
  String title = '';
  try {
    title = store.read(args[1]).title;
  } on Object {
    title = 'unreadable';
  }
  store.delete(args[1]);
  stdout.writeln('Deleted ${args[1]} — $title');
  return 0;
}

int _list(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('mi list <sessions-dir>');
    return 64;
  }
  final SessionStore store = _store(args[0]);
  for (final String id in store.listIds()) {
    final Session s = store.read(id);
    stdout.writeln(
      '$id  ${s.interview.verdict.template.name.padRight(8)} '
      '${s.directions.length.toString().padLeft(4)} directions  ${s.title}',
    );
  }
  return 0;
}

String? _option(List<String> args, String name) {
  final int i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
