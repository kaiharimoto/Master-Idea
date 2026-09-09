import '../assembly/integration.dart';
import '../session/direction.dart';
import '../session/session.dart';

/// The export: a launch document built from what the client selected.
///
/// Three properties decide everything about this file.
///
/// **It contains only what the client selected.** The council never decides
/// what ships. A direction the council rated highly and the client left behind
/// does not appear here, in any form, however good it was.
///
/// **It inherits the computed integration rather than restating it.** The
/// integration was computed across the whole selection in Assembly; repeating
/// each direction's own case here would put the client back in front of forty
/// separate arguments, which is what Assembly exists to end.
///
/// **It is portable.** The receiving end may be any model, so nothing here
/// carries Claude-specific tags, tool syntax or system-prompt idioms —
/// `PitchPortability` checks that, and the check is part of the suite rather
/// than a habit.
///
/// It is assembled by this composer out of the session's own content: the
/// integrator's paragraph, the selected directions as the council stated them,
/// the client's own approved brief and answers, and the run's marked
/// assumptions. Nothing in the body is written by hand for a particular
/// session — a pitch that was would be a pitch for a session that never
/// happened.
abstract final class PitchComposer {
  static String compose(Session s) {
    final List<Direction> chosen = s.selected;
    final Integration? integration = s.integration;
    final StringBuffer b = StringBuffer();

    b
      ..writeln('# ${s.title}')
      ..writeln()
      ..writeln(
        'This is a launch document. It is the opening input to a build, not a '
        'summary of the deliberation that produced it. Everything below was '
        'chosen by the person whose project this is, out of a larger case '
        'file; what was not chosen is not here.',
      )
      ..writeln();

    b
      ..writeln('## What is being made')
      ..writeln();
    if (integration != null && integration.becomes.trim().isNotEmpty) {
      b
        ..writeln(integration.becomes)
        ..writeln();
    }
    b
      ..writeln(
        'The brief the client approved before any of this was explored, '
        'which the work still has to hold to:',
      )
      ..writeln()
      ..writeln(s.interview.brief.restatement)
      ..writeln();

    b
      ..writeln('## The directions that were chosen')
      ..writeln();
    for (final Direction d in chosen) {
      b
        ..writeln('### ${d.title}')
        ..writeln()
        ..writeln(d.statement)
        ..writeln()
        ..writeln('How it works: ${d.mechanism}')
        ..writeln()
        ..writeln('This is the ${d.ambition.name} version of ${d.clusterName}.')
        ..writeln();
    }

    // Only pairs where both ends are in the selection. An integration
    // computed before the client changed their mind can name a direction they
    // have since dropped, and a pitch that mentions it has smuggled back in
    // something the client did not choose.
    final List<Interaction> held = <Interaction>[
      for (final Interaction i in integration?.interactions ?? <Interaction>[])
        if (s.selection.contains(i.a) && s.selection.contains(i.b)) i,
    ];
    if (integration != null && held.isNotEmpty) {
      b
        ..writeln('## How they hold together')
        ..writeln();
      for (final Interaction i in held.where(
        (Interaction i) => !i.isConflict,
      )) {
        b.writeln(
          '- ${_titleOf(s, i.a)} and ${_titleOf(s, i.b)} reinforce each '
          'other: ${i.because}',
        );
      }
      for (final Interaction i in held.where((Interaction i) => i.isConflict)) {
        b.writeln(
          '- ${_titleOf(s, i.a)} and ${_titleOf(s, i.b)} conflict: '
          '${i.because}',
        );
      }
      b.writeln();
      if (held.any((Interaction i) => i.isConflict)) {
        b
          ..writeln(
            'The conflicts are listed because they were chosen anyway. '
            'Resolving one by dropping a direction is a decision for the '
            'person whose project this is, not for whoever builds it.',
          )
          ..writeln();
      }
    }

    final List<Assumption> revisits = <Assumption>[
      for (final Assumption a in s.assumptions)
        if (a.affects.any((String id) => s.selection.contains(id))) a,
    ];
    if (revisits.isNotEmpty) {
      b
        ..writeln('## What was assumed while nobody was watching')
        ..writeln()
        ..writeln(
          'Each of these was settled by the council in the client\'s absence. '
          'They are cheap to overturn and should be treated as open until '
          'someone says otherwise.',
        )
        ..writeln();
      for (final Assumption a in revisits) {
        b.writeln(
          '- ${a.made} (${a.because})'
          '${a.isLicensed ? '' : ' — made with no declared unknown licensing it'}',
        );
      }
      b.writeln();
    }

    b
      ..writeln('## What to do with this')
      ..writeln()
      ..writeln(
        'Take the highest version of this that can actually be built, not the '
        'safest. Where a choice is not settled above, decide it and say what '
        'you decided. Where something above is assumed, treat it as a '
        'question you may reopen.',
      )
      ..writeln()
      ..writeln(machineBlock(s));

    return b.toString();
  }

  /// The machine-readable half.
  ///
  /// Line-oriented rather than JSON, for the same reason every other wire
  /// format in this pair of tools is: a document that is truncated by a paste
  /// limit loses one field here, where it would lose everything from a JSON
  /// object. It exists so Master Prompt can open a mission from this file
  /// without the client retyping four paragraphs — the values arrive there as
  /// *proposed*, never confirmed, because a value nobody has agreed to must
  /// not satisfy a readiness gate in either tool.
  static String machineBlock(Session s) {
    final Integration? i = s.integration;
    final String mission = _oneLine(
      i?.becomes.isNotEmpty ?? false
          ? i!.becomes
          : s.interview.brief.restatement,
    );
    return <String>[
      '```mi-pitch',
      'v=1',
      'session=${s.id}',
      'task=${s.taskId}',
      'title=${_oneLine(s.title)}',
      'medium=${s.interview.profileId}',
      'tier=${s.interview.verdict.templateId}',
      'mission=$mission',
      'story=${_oneLine(s.interview.brief.restatement)}',
      'scale=${_oneLine(_answer(s, 'appetite'))}',
      'audience=${_oneLine(_answer(s, 'audience'))}',
      'directions=${s.selection.join(' ')}',
      '```',
    ].join('\n');
  }

  static String _answer(Session s, String moduleId) =>
      s.interview.answerFor(moduleId)?.text ?? '';

  static String _titleOf(Session s, String id) =>
      s.directionById(id)?.title ?? id;

  static String _oneLine(String s) =>
      s.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Whether a pitch would still work in front of a model that is not Claude.
///
/// The pitch is the one artifact that leaves this pair of tools entirely, and
/// the commonest way it stops being portable is not a deliberate choice but a
/// habit: an XML-ish tag, a tool-call idiom, a system-prompt convention that
/// reads as neutral prose to whoever wrote it. So this is a check rather than
/// a rule of thumb.
abstract final class PitchPortability {
  static final List<RegExp> _tells = <RegExp>[
    RegExp(r'<', caseSensitive: false),
    RegExp(r'<function_calls>', caseSensitive: false),
    RegExp(r'<system-reminder', caseSensitive: false),
    RegExp(r'<invoke\b', caseSensitive: false),
    RegExp(r'<thinking>', caseSensitive: false),
    RegExp(r'\bYou are Claude\b', caseSensitive: false),
    RegExp(r'\bAssistant:\s*$', multiLine: true),
    RegExp(r'\bHuman:\s*$', multiLine: true),
    RegExp(r'\bclaude\.ai\b', caseSensitive: false),
    RegExp(r'\bCLAUDE\.md\b'),
    RegExp(r'--permission-mode\b'),
  ];

  /// Everything in [pitch] that ties it to one provider.
  static List<String> tells(String pitch) => <String>[
    for (final RegExp r in _tells)
      if (r.hasMatch(pitch)) r.pattern,
  ];

  static bool isPortable(String pitch) => tells(pitch).isEmpty;
}
