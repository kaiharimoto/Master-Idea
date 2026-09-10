import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/sitting.dart';
import '../widgets/carry_panel.dart';

/// The interview as it is being conducted: one question at a time, in order,
/// with what has been settled kept behind a disclosure rather than scrolling
/// above it.
///
/// **A proceeding, not a conversation.** There is no transcript and no message
/// bubble anywhere here. A chat would invite the client to chat, and what this
/// stage needs is answers specific enough that a six-hour sitting can proceed
/// without ever asking a question — because there will be nobody to ask.
class InterviewDraft extends ChangeNotifier {
  InterviewDraft({required String rawIdea}) {
    _answers['raw-idea'] = rawIdea;
  }

  /// An interview that was interrupted, read back off disk.
  factory InterviewDraft.fromJson(Map<String, Object?> j) {
    final InterviewDraft d = InterviewDraft(rawIdea: '${j['raw-idea'] ?? ''}');
    final Object? answers = j['answers'];
    if (answers is Map<String, Object?>) {
      answers.forEach((String k, Object? v) => d._answers[k] = '$v');
    }
    d._profileId = j['profileId'] as String?;
    d.restatement = '${j['restatement'] ?? ''}';
    d.tierId = '${j['tierId'] ?? ''}';
    d.tierReasoning = '${j['tierReasoning'] ?? ''}';
    d.tierBy = '${j['tierBy'] ?? 'composed'}';
    d.draftedBy = '${j['draftedBy'] ?? ''}';
    final Object? unknowns = j['unknowns'];
    if (unknowns is List<Object?>) {
      for (final Object? u in unknowns) {
        if (u is Map<String, Object?>) {
          d.unknowns.add(
            DeclaredUnknown(
              id: '${u['id']}',
              question: '${u['question']}',
              licence: '${u['licence']}',
            ),
          );
        }
      }
    }
    return d;
  }

  final Map<String, String> _answers = <String, String>{};

  String? _profileId;

  /// The medium decides which modules are essential, so the interview is
  /// composed as it goes rather than fixed at the start.
  String? get profileId => _profileId;

  set profileId(String? id) {
    _profileId = id;
    notifyListeners();
  }

  /// The declared unknowns, as the client wrote them.
  final List<DeclaredUnknown> unknowns = <DeclaredUnknown>[];

  String restatement = '';
  String tierId = '';
  String tierReasoning = '';
  String tierBy = 'composed';

  /// Who drafted the restatement on screen: a seat id, or empty while it is
  /// still the composed one.
  String draftedBy = '';

  Map<String, String> get answers => Map<String, String>.unmodifiable(_answers);

  Map<String, Object?> toJson() => <String, Object?>{
    'answers': _answers,
    'profileId': _profileId,
    'restatement': restatement,
    'tierId': tierId,
    'tierReasoning': tierReasoning,
    'tierBy': tierBy,
    'draftedBy': draftedBy,
    'unknowns': <Map<String, Object?>>[
      for (final DeclaredUnknown u in unknowns)
        <String, Object?>{
          'id': u.id,
          'question': u.question,
          'licence': u.licence,
        },
    ],
  };

  List<InterviewModule> get modules => _profileId == null
      ? <InterviewModule>[moduleById('raw-idea'), moduleById('medium')]
      : InterviewComposer.compose(profileId: _profileId!);

  /// The next module with no answer yet, or null when the questions are done.
  InterviewModule? get pending {
    for (final InterviewModule m in modules) {
      if ((_answers[m.id] ?? '').trim().isEmpty) return m;
    }
    return null;
  }

  /// How many questions this interview holds.
  ///
  /// Before the medium is chosen the composition is not known, so the widest
  /// one any medium produces stands in: the count then settles by a question
  /// or two rather than jumping from "of 2" to "of 11", which is what it did
  /// when the bank of two opening questions was the whole denominator.
  int get total => _profileId == null ? _widestComposition : modules.length;

  static final int _widestComposition = domainProfiles
      .map(
        (DomainProfile p) => InterviewComposer.compose(profileId: p.id).length,
      )
      .reduce((int a, int b) => a > b ? a : b);

  int get asked => modules
      .where((InterviewModule m) => (_answers[m.id] ?? '').trim().isNotEmpty)
      .length;

  void answer(String moduleId, String text) {
    _answers[moduleId] = text.trim();
    notifyListeners();
  }

  /// Take an answer back, so the next question is that one again.
  ///
  /// Nothing is frozen until the gate closes, and a client who mistyped
  /// question three should not have to abandon fifteen answers to fix it.
  void unanswer(String moduleId) {
    _answers.remove(moduleId);
    notifyListeners();
  }

  void declare(String question, String licence) {
    unknowns.add(
      DeclaredUnknown(
        id: 'u-${unknowns.length + 1}',
        question: question,
        licence: licence.isEmpty
            ? 'Assume whatever the work needs, and mark it.'
            : licence,
      ),
    );
    notifyListeners();
  }

  void withdraw(DeclaredUnknown u) {
    unknowns.remove(u);
    notifyListeners();
  }

  /// The answers so far, as the record stores them.
  List<InterviewAnswer> get answered {
    final DateTime now = DateTime.now().toUtc();
    return <InterviewAnswer>[
      for (final InterviewModule m in modules)
        if ((_answers[m.id] ?? '').trim().isNotEmpty)
          InterviewAnswer(
            moduleId: m.id,
            question: m.question,
            text: _answers[m.id]!.trim(),
            at: now,
          ),
    ];
  }

  /// The draft the client is shown the instant the questions are done.
  InterviewAdvice get composed => InterviewCounsel.compose(answered);

  /// Take the clerk's draft.
  void take(InterviewAdvice advice, {required bool replaceBrief}) {
    if (replaceBrief) restatement = advice.restatement;
    draftedBy = advice.by;
    tierId = advice.verdict.templateId;
    tierReasoning = advice.verdict.reasoning;
    tierBy = advice.verdict.by;
    notifyListeners();
  }

  ScaleVerdict get verdict => tierId.isEmpty
      ? composed.verdict
      : ScaleVerdict(templateId: tierId, reasoning: tierReasoning, by: tierBy);

  /// Everything the gate still wants.
  List<GateRefusal> refusals() {
    if (_profileId == null) {
      return const <GateRefusal>[GateRefusal('No medium has been chosen yet.')];
    }
    return InterviewGate.refusals(close());
  }

  /// Freeze it. Nothing after this may re-elicit an answer.
  InterviewRecord close() {
    final DateTime now = DateTime.now().toUtc();
    final List<InterviewModule> used = modules;
    return InterviewRecord(
      profileId: _profileId ?? 'software',
      moduleOrder: <String>[for (final InterviewModule m in used) m.id],
      answers: answered,
      brief: ConfirmedBrief(restatement: restatement.trim(), approvedAt: now),
      unknowns: List<DeclaredUnknown>.unmodifiable(unknowns),
      verdict: verdict,
      closedAt: now,
    );
  }
}

/// The proceeding itself.
class InterviewProceeding extends StatefulWidget {
  const InterviewProceeding({
    required this.draft,
    required this.library,
    required this.sitting,
    required this.onAbandoned,
    super.key,
  });

  final InterviewDraft draft;
  final Library library;
  final Sitting sitting;
  final VoidCallback onAbandoned;

  @override
  State<InterviewProceeding> createState() => _InterviewProceedingState();
}

class _InterviewProceedingState extends State<InterviewProceeding> {
  final TextEditingController _field = TextEditingController();
  final TextEditingController _unknown = TextEditingController();
  final TextEditingController _licence = TextEditingController();
  final TextEditingController _brief = TextEditingController();
  bool _closing = false;
  bool _seenGate = false;
  bool _askedTheClerk = false;
  bool _briefEdited = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    _brief.addListener(() {
      // Once the client has touched it, nothing overwrites it — not the
      // council's draft and not a rebuild. Their words outrank both.
      if (_brief.text.trim() != widget.draft.restatement.trim()) {
        _briefEdited = true;
      }
    });
    widget.draft.addListener(_keep);
  }

  @override
  void dispose() {
    widget.draft.removeListener(_keep);
    _field.dispose();
    _unknown.dispose();
    _licence.dispose();
    _brief.dispose();
    super.dispose();
  }

  /// Every change, straight to disk. An interview is the one stage where all
  /// of the client's work happens, and it used to live in this widget's state.
  void _keep() => widget.library.saveDraft(widget.draft.toJson());

  void _answer(InterviewModule m) {
    final String said = _field.text.trim();
    if (said.isEmpty) return;
    widget.draft.answer(m.id, said);
    _field.clear();
    setState(() {});
  }

  void _change(String moduleId) {
    _field.text = widget.draft.answers[moduleId] ?? '';
    widget.draft.unanswer(moduleId);
    setState(() {});
  }

  /// Put the answers to the clerk, whose job this is.
  Future<void> _askTheClerk() async {
    setState(() => _askedTheClerk = true);
    final InterviewAdvice? advice = await widget.sitting.counsel(
      answers: widget.draft.answered,
      profileId: widget.draft.profileId ?? 'software',
      settings: widget.library.settings,
    );
    if (!mounted || advice == null) return;
    widget.draft.take(advice, replaceBrief: !_briefEdited);
    if (!_briefEdited) {
      _brief.text = advice.restatement;
      _briefEdited = false;
    }
    setState(() {});
  }

  Future<void> _open() async {
    setState(() {
      _closing = true;
      _problem = null;
    });
    try {
      widget.draft.restatement = _brief.text;
      await widget.library.begin(widget.draft.close());
    } on StateError catch (e) {
      setState(() => _problem = e.message);
    } on Object catch (e) {
      // Not only the gate. A full interview typed into a device whose disk is
      // full deserves to be told, rather than watching a button do nothing.
      setState(() => _problem = 'The session could not be opened. $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InterviewDraft d = widget.draft;

    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[d, widget.sitting]),
      builder: (BuildContext context, _) {
        final InterviewModule? m = d.pending;
        final MiColors c = MiTheme.colorsOf(context);

        if (m == null && !_seenGate) {
          // Arriving at the gate for the first time: seed the brief with the
          // composed draft, then ask the clerk to do it properly.
          _seenGate = true;
          if (_brief.text.trim().isEmpty) {
            _brief.text = d.restatement.isNotEmpty
                ? d.restatement
                : d.composed.restatement;
            _briefEdited = false;
          }
          if (widget.sitting.canDrive && !_askedTheClerk) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _askTheClerk());
          }
        }

        // One question on screen, and the record of what has been settled
        // folded away beneath it. A transcript would invite chatting, and what
        // this stage needs is answers specific enough that a sitting can run
        // for hours without ever having to ask.
        return MiFocal(
          eyebrow: m == null
              ? 'The interview is finished'
              : 'Question ${d.asked + 1} of ${d.total} · ${m.produces.name}',
          question: m == null ? 'Approve the brief' : m.question,
          supporting: m == null
              ? 'This is the council\'s restatement of your idea. Correct it '
                    'until it is right: once the sitting opens it is '
                    'constitution, and nothing the council produces may '
                    'contradict it. Nobody will ask you again.'
              : m.whyItMatters,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: m == null ? _gate(c, d) : _question(c, d, m),
          ),
          primary: m == null
              ? null
              : (m.id == 'medium'
                    ? null
                    : MiButton(
                        label: 'Record',
                        kind: MiButtonKind.primary,
                        expand: true,
                        onPressed: () => _answer(m),
                      )),
          secondary: MiButton(
            label: 'Abandon this interview',
            kind: MiButtonKind.quiet,
            expand: true,
            onPressed: () async {
              final bool go = await showMiConfirm(
                context,
                title: 'Abandon this interview?',
                body:
                    'Everything you have said here goes with it. Nothing has '
                    'been put before the council yet, so there is nothing to '
                    'come back to.',
                action: 'Abandon it',
                cancel: 'Keep going',
              );
              if (!go) return;
              await widget.library.clearDraft();
              widget.onAbandoned();
            },
          ),
          disclosures: <Widget>[
            MiDisclosure(
              label: 'What has been settled',
              trailingNote: '${d.answers.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final MapEntry<String, String> e in d.answers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MiSpace.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: MiRecord(
                              label: _nameOf(e.key),
                              value: e.value,
                              style: MiType.caption,
                            ),
                          ),
                          // Nothing is frozen until the gate closes, and a
                          // typo in question three should not cost fifteen
                          // answers to fix.
                          MiButton(
                            label: 'Change',
                            kind: MiButtonKind.quiet,
                            onPressed: () => _change(e.key),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// A module id the running build may not know, because the draft on disk was
  /// written by another one.
  static String _nameOf(String moduleId) {
    try {
      return moduleById(moduleId).name;
    } on ArgumentError {
      return moduleId;
    }
  }

  List<Widget> _question(MiColors c, InterviewDraft d, InterviewModule m) {
    // The medium is the one question with a fixed set of answers, because it
    // selects the domain profile — and a profile changes what counts as a good
    // direction rather than merely how one is worded.
    if (m.id == 'medium') {
      return <Widget>[
        for (final DomainProfile p in domainProfiles)
          Padding(
            padding: const EdgeInsets.only(bottom: MiSpace.sm),
            child: Semantics(
              button: true,
              label: p.name,
              child: InkWell(
                onTap: () {
                  d
                    ..profileId = p.id
                    ..answer('medium', p.name);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: MiSpace.sm,
                    horizontal: MiSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(p.name, style: MiType.body.copyWith(color: c.ink)),
                      Text(
                        p.goodDirection,
                        style: MiType.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ];
    }

    return <Widget>[
      // How far in, without a denominator that jumps: the medium answer
      // changes how many questions there are, and "question 3 of 2" is what
      // the count used to say.
      Align(
        alignment: Alignment.centerLeft,
        child: MiSteps(step: d.asked + 1, total: d.total),
      ),
      const SizedBox(height: MiSpace.md),
      MiWriting(
        controller: _field,
        autofocus: true,
        hint: 'In your own words.',
        onSubmit: () => _answer(m),
      ),
      const SizedBox(height: MiSpace.sm),
      Text(
        '${MiSubmit.hintFor(context)} records it.',
        style: MiType.caption.copyWith(color: c.inkFaint),
      ),
    ];
  }

  /// The gate: the restatement the client approves, the unknowns the sitting
  /// is licensed to settle, and the tier.
  List<Widget> _gate(MiColors c, InterviewDraft d) {
    final ScaleVerdict verdict = d.verdict;
    final List<GateRefusal> refusals = <GateRefusal>[
      for (final GateRefusal r in _refusalsNow(d)) r,
    ];
    final CouncilTurn? carrying = widget.sitting.hand?.waiting;

    return <Widget>[
      MiWriting(controller: _brief, minLines: 4, maxLines: 14),
      const SizedBox(height: MiSpace.xs),
      Row(
        children: <Widget>[
          Expanded(
            child: Text(
              widget.sitting.phase == SittingPhase.deliberating
                  ? 'The clerk is drafting this from what you said…'
                  : d.draftedBy.isEmpty
                  ? 'Composed from your answers. The clerk can draft it '
                        'properly.'
                  : 'Drafted by ${d.draftedBy} from your answers, and yours to '
                        'correct.',
              style: MiType.caption.copyWith(color: c.inkFaint),
            ),
          ),
          if (!widget.sitting.isBusy)
            MiButton(
              label: d.draftedBy.isEmpty ? 'Ask the council' : 'Ask again',
              kind: MiButtonKind.quiet,
              onPressed: _askTheClerk,
            ),
        ],
      ),
      if (carrying != null) ...<Widget>[
        const SizedBox(height: MiSpace.md),
        CarryPanel(hand: widget.sitting.hand!, turn: carrying),
      ],
      const SizedBox(height: MiSpace.xl),
      const MiRule(),
      const SizedBox(height: MiSpace.lg),
      Text(
        'What may the council settle without you?',
        style: MiType.title.copyWith(color: c.ink),
      ),
      const SizedBox(height: MiSpace.xs),
      Text(
        'Every assumption it makes against one of these is marked in the '
        'dossier as a revisit point you can cheaply overturn. With none '
        'declared, the sitting has no licence to decide anything and stalls '
        'the first time it needs to.',
        style: MiType.prose.copyWith(color: c.inkMuted),
      ),
      const SizedBox(height: MiSpace.md),
      for (final DeclaredUnknown u in d.unknowns)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: MiRecord(
                label: 'Unknown',
                value: '${u.question} — ${u.licence}',
              ),
            ),
            MiButton(
              label: 'Withdraw',
              kind: MiButtonKind.quiet,
              onPressed: () => d.withdraw(u),
            ),
          ],
        ),
      const SizedBox(height: MiSpace.sm),
      MiWriting(
        controller: _unknown,
        minLines: 1,
        maxLines: 3,
        hint: 'What you do not know.',
      ),
      const SizedBox(height: MiSpace.sm),
      MiWriting(
        controller: _licence,
        minLines: 1,
        maxLines: 3,
        hint: 'What the council may do about it.',
      ),
      const SizedBox(height: MiSpace.sm),
      MiButton(
        label: 'Declare it',
        kind: MiButtonKind.secondary,
        onPressed: () {
          if (_unknown.text.trim().isEmpty) {
            miNotice(context, 'Say what you do not know first.');
            return;
          }
          d.declare(_unknown.text.trim(), _licence.text.trim());
          _unknown.clear();
          _licence.clear();
          setState(() {});
        },
      ),
      const SizedBox(height: MiSpace.xl),
      const MiRule(),
      const SizedBox(height: MiSpace.lg),
      Text('The sitting', style: MiType.title.copyWith(color: c.ink)),
      const SizedBox(height: MiSpace.xs),
      MiRecord(label: 'Judged', value: verdict.reasoning),
      const SizedBox(height: MiSpace.sm),
      Wrap(
        spacing: MiSpace.sm,
        runSpacing: MiSpace.sm,
        children: <Widget>[
          for (final HarnessTemplate t in harnessTemplates)
            MiButton(
              label: t.name,
              kind: t.id != verdict.templateId
                  ? MiButtonKind.secondary
                  : MiButtonKind.primary,
              onPressed: () {
                final ScaleVerdict judged = d.draftedBy.isEmpty
                    ? d.composed.verdict
                    : ScaleVerdict(
                        templateId: d.tierId,
                        reasoning: d.tierReasoning,
                        by: d.tierBy,
                      );
                d
                  ..tierId = t.id
                  ..tierBy = t.id == judged.templateId ? judged.by : 'client'
                  ..tierReasoning = t.id == judged.templateId
                      ? judged.reasoning
                      : 'Chosen by the client over the '
                            '${templateById(judged.templateId).name} the '
                            'council judged.';
                setState(() {});
              },
            ),
        ],
      ),
      const SizedBox(height: MiSpace.xs),
      Text(
        templateById(verdict.templateId).expectation,
        style: MiType.caption.copyWith(color: c.inkMuted),
      ),
      const SizedBox(height: MiSpace.xl),

      // What the gate still wants, while it still wants it — rather than as a
      // paragraph of refusals after the client has pressed the button.
      if (refusals.isNotEmpty) ...<Widget>[
        MiPanel(
          accent: c.warning,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Before the sitting can open',
                style: MiType.label.copyWith(color: c.ink),
              ),
              const SizedBox(height: MiSpace.xs),
              for (final GateRefusal r in refusals)
                Text(
                  '· ${r.reason}',
                  style: MiType.caption.copyWith(color: c.inkMuted),
                ),
            ],
          ),
        ),
        const SizedBox(height: MiSpace.md),
      ],
      if (_problem != null) ...<Widget>[
        Text(_problem!, style: MiType.body.copyWith(color: c.warning)),
        const SizedBox(height: MiSpace.md),
      ],
      MiButton(
        label: 'Close the interview and open the sitting',
        kind: MiButtonKind.primary,
        expand: true,
        busy: _closing,
        onPressed: refusals.isNotEmpty || _closing ? null : _open,
      ),
      const SizedBox(height: MiSpace.sm),
      Text(
        'The interview happens once. After this the council does not ask '
        'anything, because there is nobody to ask.',
        style: MiType.caption.copyWith(color: c.inkMuted),
      ),
    ];
  }

  /// The gate's refusals against the brief as it stands in the field, not as
  /// it was last committed to the draft.
  List<GateRefusal> _refusalsNow(InterviewDraft d) {
    final String was = d.restatement;
    d.restatement = _brief.text;
    final List<GateRefusal> refusals = d.refusals();
    d.restatement = was;
    return refusals;
  }
}
