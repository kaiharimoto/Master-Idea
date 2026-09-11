import 'package:mi_core/mi_core.dart';

/// A clock that never waits.
///
/// A limit pause is measured in hours, so a test that waited one out would
/// take hours; a test that skipped the wait would not exercise the pause at
/// all. This does the third thing: it jumps to the moment asked for and
/// records that it was asked, so both the pause and its exclusion from council
/// time are provable in milliseconds.
class FakeClock implements RunClock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 3, 1, 9);

  DateTime _now;
  final List<Duration> waited = <Duration>[];

  @override
  DateTime now() {
    // Advance a second per reading, so two records taken in one round do not
    // share a timestamp and an ordering bug cannot hide behind equal times.
    _now = _now.add(const Duration(seconds: 1));
    return _now;
  }

  @override
  Future<void> waitUntil(DateTime when) async {
    final Duration d = when.difference(_now);
    if (d.isNegative) return;
    waited.add(d);
    _now = when;
  }
}

/// A council that answers in the real grammar without a process.
///
/// It reads the vocabulary out of the prompt it was given rather than being
/// told the rungs, which means a prompt that stopped carrying its vocabulary
/// would fail these tests — the double is checking the prompt, not just
/// standing in for a model.
class ScriptedCouncil implements CouncilTransport {
  ScriptedCouncil({
    this.perAngle = 2,
    this.silentFromRound = 3,
    this.pauseOnCall,
    this.pauseUntilCall,
    this.stopOnCall,
    this.failOnCall,
    this.unsourcedInRound,
    this.dissentEvery = 3,
    this.onCall,
  });

  /// Called with the running call count on every call, before it is
  /// answered, so a test can act on the run — hold it, say — from inside a
  /// turn, at the one moment the timing is not left to chance.
  final void Function(int calls)? onCall;

  /// How many directions each angle returns while it still has any.
  final int perAngle;

  /// The round from which every angle returns `mi-none`, which is what takes
  /// the run to dryness.
  final int silentFromRound;

  /// Raise a session limit on the nth call, once.
  final int? pauseOnCall;

  /// Raise a session limit on every call up to this one, so a run has to sit
  /// through more waits than any retry budget would have allowed.
  final int? pauseUntilCall;

  /// The client stopped the sitting on the nth call.
  final int? stopOnCall;

  /// The transport failed on the nth call for a reason that is not a limit.
  final int? failOnCall;

  /// Return a direction citing an interview answer that does not exist, to
  /// prove the run refuses it rather than storing an unsourced direction.
  final int? unsourcedInRound;

  final int dissentEvery;

  int calls = 0;

  /// Answers already used as a direction's only source, and answer/gap pairs
  /// already used. A prospector that reuses either is producing a direction
  /// the traceability invariant cannot tell apart from one already on record,
  /// so the double keeps the books the way a real seat would have to.
  final Set<String> _lone = <String>{};
  final Set<String> _pairs = <String>{};
  int _rated = 0;
  bool _paused = false;
  final List<CouncilTurn> seen = <CouncilTurn>[];

  @override
  Future<CouncilReply> ask(CouncilTurn turn) async {
    calls++;
    seen.add(turn);
    onCall?.call(calls);
    if (pauseOnCall != null && calls == pauseOnCall && !_paused) {
      _paused = true;
      throw CouncilPaused(
        'session',
        '5-hour limit reached',
        DateTime.utc(2026, 3, 1, 14),
      );
    }
    if (pauseUntilCall != null && calls <= pauseUntilCall!) {
      throw CouncilPaused(
        'session',
        '5-hour limit reached',
        DateTime.utc(2026, 3, 1, 9).add(Duration(hours: calls)),
        source: 'stated',
      );
    }
    if (stopOnCall != null && calls == stopOnCall) {
      throw CouncilStopped(DateTime.utc(2026, 3, 1, 10));
    }
    if (failOnCall != null && calls == failOnCall) {
      throw CouncilUnavailable('The CLI exited with 1: not logged in');
    }
    switch (turn.purpose) {
      case 'propose':
        return CouncilReply(
          text: _propose(turn),
          tokensIn: 900,
          tokensOut: 300,
        );
      case 'challenge':
        return const CouncilReply(
          text:
              'mi-challenge\n'
              'attack=The mechanism assumes an audience that has to be built '
              'first.\n'
              'fatal=no\n'
              'end',
          tokensIn: 400,
          tokensOut: 80,
        );
      case 'rate':
        _rated++;
        final List<String> rungs = _rungsIn(turn.prompt);
        final String verdict = rungs[(_rated + 1) % rungs.length];
        return CouncilReply(
          text:
              'mi-rating\n'
              'verdict=$verdict\n'
              'because=Judged on the direction as written, without knowing '
              'who wrote it.\n'
              'end',
          tokensIn: 600,
          tokensOut: 60,
        );
      case 'dissent':
        final List<String> rungs = _rungsIn(turn.prompt);
        if (_rated % dissentEvery != 0) {
          return const CouncilReply(text: 'mi-none');
        }
        final String onRecord = _fieldIn(turn.prompt, 'verdict');
        final String other = rungs.firstWhere(
          (String r) => r != onRecord,
          orElse: () => rungs.first,
        );
        return CouncilReply(
          text:
              'mi-dissent\n'
              'verdict=$other\n'
              'because=The record reads the mechanism more generously than it '
              'deserves.\n'
              'end',
        );
      case 'map':
        return CouncilReply(text: _map(turn));
      case 'integrate':
        return const CouncilReply(
          text:
              'mi-integration\n'
              'becomes=One thing rather than three: a proceeding that '
              'interrogates the client once and then argues with itself until '
              'it has nothing left to say.\n'
              'reinforces=d-0001|d-0002|Both depend on the client being absent '
              'during the deliberation.\n'
              'conflicts=d-0001|d-0003|One wants a long unattended run, the '
              'other wants a result inside an afternoon.\n'
              'end',
        );
      default:
        return const CouncilReply(text: 'mi-none');
    }
  }

  String _propose(CouncilTurn turn) {
    final int round = turn.agent.round;
    if (round >= silentFromRound) return 'mi-none';
    final String angle = turn.conversation.split('-').skip(2).join('-');
    if (unsourcedInRound == round) {
      return 'mi-direction\n'
          'cluster=What the thing is for\n'
          'ambition=ambitious\n'
          'title=Cites nothing that exists\n'
          'statement=A direction whose source is a module the client was '
          'never asked.\n'
          'mechanism=It would work by pretending the interview covered it.\n'
          'trace-answer=module-that-was-never-put\n'
          'quote=nothing\n'
          'end';
    }
    // Trace to whatever the prompt actually put in front of this seat, the
    // way a real prospector must: an answer it can see, and a gap once the
    // cartographer has named one. Sourcing everything to the same answer is
    // how one sentence from the client gets stretched over an afternoon, and
    // the suite refuses it.
    final List<String> answers = _idsUnder(turn.prompt, 'WHAT THE CLIENT SAID');
    final List<String> gaps = _idsUnder(turn.prompt, 'OPEN GAPS IN THE MAP');
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < perAngle; i++) {
      // Every angle's first proposal is the same idea, arrived at from a
      // different direction. A real council converges like this constantly,
      // and it is what the deduplicator — and therefore the whole meaning of
      // 'nothing new came back' — exists for.
      final String key = i == 0 ? 'the-obvious-one' : '$angle-r$round-$i';
      final (String, String?) source = _source(answers, gaps);
      final String answer = source.$1;
      final String? gap = source.$2;
      b
        ..writeln('mi-direction')
        ..writeln('cluster=${_cluster(i)}')
        ..writeln('ambition=${_ambition(i)}')
        ..writeln('title=Direction $key')
        ..writeln(
          'statement=Treat the idea as $key demands: '
          '${_uniqueWords(key)} instead of what the client described.',
        )
        ..writeln(
          'mechanism=Concretely, ${_uniqueWords('m-$key')} is built first and '
          'everything else follows from it.',
        )
        ..writeln('trace-answer=$answer');
      if (gap != null) {
        b.writeln('trace-gap=$gap');
      }
      b
        ..writeln('quote=the idea as the client first said it')
        ..writeln('end');
    }
    b
      ..writeln('mi-assumption')
      ..writeln('made=The client would rather wait than be asked again.')
      ..writeln('because=No answer covered interruption.')
      ..writeln('unknown=u-interruption')
      ..writeln('end');
    return b.toString();
  }

  String _map(CouncilTurn turn) {
    final int round = turn.agent.round;
    final StringBuffer b = StringBuffer()
      ..writeln('mi-territory')
      ..writeln('id=t-purpose-r$round')
      ..writeln('name=What the thing is for, round $round')
      ..writeln('description=The territory of purposes the idea could serve.')
      ..writeln('status=explored')
      ..writeln('end')
      ..writeln('mi-territory')
      ..writeln('id=t-dropped-r$round')
      ..writeln('name=Commercial licensing, round $round')
      ..writeln('description=Selling the output as a service to other people.')
      ..writeln('status=dropped')
      ..writeln('reason=The client declared it out of bounds in the interview.')
      ..writeln('end');
    // Several gaps per barrier, not one. A map that names a single gap a
    // round cannot distinguish two directions that answer the same client
    // sentence, and the traceability invariant refuses both of them.
    for (int i = 0; i < 4; i++) {
      b
        ..writeln('mi-territory')
        ..writeln('id=t-gap-r$round-$i')
        ..writeln('name=Unentered territory $i, round $round')
        ..writeln('description=Nobody has looked here yet.')
        ..writeln('status=gap')
        ..writeln('end');
    }
    return b.toString();
  }

  static String _cluster(int i) => switch (i % 3) {
    0 => 'What the thing is for',
    1 => 'What it refuses to do',
    _ => 'Who it belongs to',
  };

  static String _ambition(int i) => switch (i % 3) {
    0 => 'conservative',
    1 => 'ambitious',
    _ => 'reckless',
  };

  /// Distinct enough that the deduplicator keeps them apart, which is what
  /// makes 'nothing new came back' mean something in these tests.
  static String _uniqueWords(String key) => key
      .split('')
      .where((String c) => RegExp('[a-z0-9]').hasMatch(c))
      .map((String c) => 'w$c${key.hashCode.abs() % 97}')
      .join(' ');

  /// Pick a source no other direction is already using.
  ///
  /// While the map is empty — which is only ever the first round — a direction
  /// can be told apart from its neighbours only by which answer it came from,
  /// so each takes a fresh one. Once the cartographer has named gaps, every
  /// direction takes an answer-and-gap pair nobody else holds, which is what
  /// the traceability invariant demands of a real seat too.
  (String, String?) _source(List<String> answers, List<String> gaps) {
    final List<String> pool = answers.isEmpty ? <String>['raw-idea'] : answers;
    if (gaps.isEmpty) {
      for (final String a in pool) {
        if (!_lone.contains(a)) {
          _lone.add(a);
          return (a, null);
        }
      }
      return (pool.first, null);
    }
    for (final String a in pool) {
      if (_lone.contains(a)) continue;
      for (final String g in gaps) {
        if (_pairs.add('$a|$g')) return (a, g);
      }
    }
    return (pool.first, gaps.first);
  }

  /// The bracketed ids the prompt listed under a heading, which is all a
  /// prospector knows about what it may cite.
  static List<String> _idsUnder(String prompt, String heading) {
    final List<String> lines = prompt.split('\n');
    final int start = lines.indexWhere((String l) => l.startsWith(heading));
    if (start < 0) return const <String>[];
    final List<String> out = <String>[];
    for (final String line in lines.skip(start)) {
      final RegExpMatch? m = RegExp(
        r'^\[([a-z0-9-]+)\]',
      ).firstMatch(line.trim());
      if (m != null) {
        out.add(m.group(1)!);
      }
      if (out.isNotEmpty && line.trim().isEmpty) break;
    }
    return out;
  }

  static List<String> _rungsIn(String prompt) {
    final List<String> lines = prompt.split('\n');
    final int i = lines.indexWhere(
      (String l) => l.trim() == 'ANSWER WITH EXACTLY ONE OF',
    );
    if (i < 0 || i + 1 >= lines.length) {
      throw StateError('the rating prompt no longer carries its vocabulary');
    }
    return lines[i + 1].split(',').map((String s) => s.trim()).toList();
  }

  static String _fieldIn(String prompt, String key) {
    for (final String line in prompt.split('\n')) {
      if (line.startsWith('$key=')) {
        return line.substring(key.length + 1).trim();
      }
    }
    return '';
  }
}

/// An interview that has passed the gate, ready for a run.
InterviewRecord referenceInterview({String templateId = 'hearing'}) {
  final DateTime at = DateTime.utc(2026, 3, 1, 8);
  final List<InterviewModule> composed = InterviewComposer.compose(
    profileId: 'software',
  );
  return InterviewRecord(
    profileId: 'software',
    moduleOrder: <String>[for (final InterviewModule m in composed) m.id],
    answers: <InterviewAnswer>[
      for (final InterviewModule m in composed)
        InterviewAnswer(
          moduleId: m.id,
          question: m.question,
          text:
              'The client\'s answer about ${m.name.toLowerCase()}, given '
              'in their own words and stored exactly as they gave it.',
          at: at,
        ),
    ],
    brief: ConfirmedBrief(
      restatement:
          'A tool that interrogates one raw idea hard, then argues with '
          'itself unattended until it has nothing left to say, and hands back '
          'a case file the client can audit.',
      approvedAt: at,
    ),
    unknowns: const <DeclaredUnknown>[
      DeclaredUnknown(
        id: 'u-interruption',
        question: 'Whether the client wants to be interrupted mid-run.',
        licence: 'Assume not, and mark it.',
      ),
    ],
    verdict: ScaleVerdict(
      templateId: templateId,
      reasoning: 'The idea has one plausible shape and a short horizon.',
    ),
    closedAt: at,
  );
}

Session referenceSession({String templateId = 'hearing'}) {
  final InterviewRecord interview = referenceInterview(templateId: templateId);
  return Session(
    id: 'sess-ref',
    taskId: 'reference-session',
    title: 'Reference session',
    createdAt: DateTime.utc(2026, 3, 1, 8),
    interview: interview,
    manifest: RunManifest(
      sessionId: 'sess-ref',
      templateId: templateId,
      tier: templateById(templateId).tier,
      transport: 'cli',
      startedAt: DateTime.utc(2026, 3, 1, 9),
    ),
  );
}
