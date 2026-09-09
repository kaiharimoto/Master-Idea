import 'package:mi_core/mi_core.dart';

/// A clock that never waits. See `mi_core`'s copy for why one exists at all;
/// this package needs its own because a test package cannot import another
/// package's test directory.
class FakeClock implements RunClock {
  FakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026, 3, 1, 9);

  DateTime _now;
  final List<Duration> waited = <Duration>[];

  @override
  DateTime now() {
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
              'The client\'s answer about ${m.name.toLowerCase()}, stored '
              'exactly as they gave it.',
          at: at,
        ),
    ],
    brief: ConfirmedBrief(
      restatement:
          'A tool that interrogates one raw idea hard, then argues with '
          'itself unattended until it has nothing left to say.',
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
      reasoning: 'One plausible shape and a short horizon.',
    ),
    closedAt: at,
  );
}

Session referenceSession({String templateId = 'hearing'}) => Session(
  id: 'sess-ref',
  taskId: 'reference-session',
  title: 'Reference session',
  createdAt: DateTime.utc(2026, 3, 1, 8),
  interview: referenceInterview(templateId: templateId),
  manifest: RunManifest(
    sessionId: 'sess-ref',
    templateId: templateId,
    tier: templateById(templateId).tier,
    transport: 'cli',
    startedAt: DateTime.utc(2026, 3, 1, 9),
  ),
);
