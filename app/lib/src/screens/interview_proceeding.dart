import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';

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

  Map<String, String> get answers => Map<String, String>.unmodifiable(_answers);

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

  int get asked => modules
      .where((InterviewModule m) => (_answers[m.id] ?? '').trim().isNotEmpty)
      .length;

  void answer(String moduleId, String text) {
    _answers[moduleId] = text.trim();
    notifyListeners();
  }

  /// A restatement of the idea, composed from what the client has said.
  ///
  /// The tool moves first here too: the client is shown a restatement to
  /// correct rather than an empty box to fill. **It is their approval that
  /// makes it constitution**, so it is editable and nothing proceeds until
  /// they have accepted it in their own words.
  String draftRestatement() {
    final String idea = _answers['raw-idea'] ?? '';
    final String audience = _answers['audience'] ?? '';
    final String ceiling = _answers['ceiling'] ?? '';
    final String alternatives = _answers['existing-alternatives'] ?? '';
    return <String>[
      idea,
      if (audience.isNotEmpty) 'It is for $audience',
      if (alternatives.isNotEmpty) 'It exists alongside $alternatives',
      if (ceiling.isNotEmpty) 'At its highest, $ceiling',
    ].join('. ').replaceAll('..', '.');
  }

  /// The tier this idea appears to warrant, and why.
  ///
  /// Judged from the appetite answer rather than asked outright, because asked
  /// outright everyone picks the longest sitting and a six-hour run on a
  /// postcard produces a hundred directions about a postcard.
  ScaleVerdict draftVerdict() {
    final String appetite = (_answers['appetite'] ?? '').toLowerCase();
    final String ceiling = (_answers['ceiling'] ?? '');
    bool says(List<String> words) => words.any(appetite.contains);

    if (says(<String>['year', 'life', 'career', 'decade'])) {
      return const ScaleVerdict(
        templateId: 'assize',
        reasoning:
            'You described this as work measured in years. An idea somebody '
            'intends to spend that long on is worth the longest sitting the '
            'council holds.',
      );
    }
    if (says(<String>['month', 'season', 'summer'])) {
      return const ScaleVerdict(
        templateId: 'session',
        reasoning:
            'Months of work, and the medium is still genuinely open. That is '
            'a sitting rather than a hearing.',
      );
    }
    if (says(<String>['week', 'fortnight'])) {
      return const ScaleVerdict(
        templateId: 'sitting',
        reasoning:
            'Weeks of work: more than one plausible shape, but not an open '
            'field.',
      );
    }
    return ScaleVerdict(
      templateId: 'hearing',
      reasoning: ceiling.length > 240
          ? 'You describe an afternoon\'s work with a ceiling far above it. '
                'The council starts with a hearing and you can convene again.'
          : 'An afternoon or a few days of work. A hearing is the right size, '
                'and a sitting that goes dry early is a sitting that was too '
                'large.',
    );
  }

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
    final ScaleVerdict verdict = tierId.isEmpty
        ? draftVerdict()
        : ScaleVerdict(templateId: tierId, reasoning: tierReasoning);
    return InterviewRecord(
      profileId: _profileId ?? 'software',
      moduleOrder: <String>[for (final InterviewModule m in used) m.id],
      answers: <InterviewAnswer>[
        for (final InterviewModule m in used)
          if ((_answers[m.id] ?? '').trim().isNotEmpty)
            InterviewAnswer(
              moduleId: m.id,
              question: m.question,
              text: _answers[m.id]!.trim(),
              at: now,
            ),
      ],
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
    required this.onAbandoned,
    super.key,
  });

  final InterviewDraft draft;
  final Library library;
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
  String? _problem;

  @override
  void dispose() {
    _field.dispose();
    _unknown.dispose();
    _licence.dispose();
    _brief.dispose();
    super.dispose();
  }

  void _answer(InterviewModule m) {
    final String said = _field.text.trim();
    if (said.isEmpty) return;
    widget.draft.answer(m.id, said);
    _field.clear();
    setState(() {});
  }

  Future<void> _open() async {
    setState(() {
      _closing = true;
      _problem = null;
    });
    try {
      await widget.library.begin(widget.draft.close());
    } on StateError catch (e) {
      setState(() => _problem = e.message);
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final InterviewDraft d = widget.draft;

    return ListenableBuilder(
      listenable: d,
      builder: (BuildContext context, _) {
        final InterviewModule? m = d.pending;
        final MiColors c = MiTheme.colorsOf(context);

        // One question on screen, and the record of what has been settled
        // folded away beneath it. A transcript would invite chatting, and what
        // this stage needs is answers specific enough that a sitting can run
        // for hours without ever having to ask.
        return MiFocal(
          eyebrow: m == null
              ? 'The interview is finished'
              : 'Question ${d.asked + 1} of ${d.modules.length} · '
                    '${m.produces.name}',
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
              ? MiButton(
                  label: 'Close the interview and open the sitting',
                  kind: MiButtonKind.primary,
                  expand: true,
                  busy: _closing,
                  onPressed: () {
                    d.restatement = _brief.text;
                    _open();
                  },
                )
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
            onPressed: widget.onAbandoned,
          ),
          disclosures: <Widget>[
            MiDisclosure(
              label: 'What has been settled',
              trailingNote: '${d.answers.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final MapEntry<String, String> e in d.answers.entries)
                    MiRecord(
                      label: moduleById(e.key).name,
                      value: e.value,
                      style: MiType.caption,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
      ];
    }

    return <Widget>[
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
    if (_brief.text.isEmpty && d.restatement.isEmpty) {
      _brief.text = d.draftRestatement();
    }
    final ScaleVerdict verdict = d.tierId.isEmpty
        ? d.draftVerdict()
        : ScaleVerdict(templateId: d.tierId, reasoning: d.tierReasoning);

    return <Widget>[
      MiWriting(controller: _brief, minLines: 4, maxLines: 14),
      const SizedBox(height: MiSpace.xl),
      MiRule(),
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
        MiRecord(label: 'Unknown', value: '${u.question} — ${u.licence}'),
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
        onPressed: () {
          if (_unknown.text.trim().isEmpty) return;
          d.unknowns.add(
            DeclaredUnknown(
              id: 'u-${d.unknowns.length + 1}',
              question: _unknown.text.trim(),
              licence: _licence.text.trim().isEmpty
                  ? 'Assume whatever the work needs, and mark it.'
                  : _licence.text.trim(),
            ),
          );
          _unknown.clear();
          _licence.clear();
          setState(() {});
        },
        kind: MiButtonKind.secondary,
      ),
      const SizedBox(height: MiSpace.xl),
      MiRule(),
      const SizedBox(height: MiSpace.lg),
      Text('The sitting', style: MiType.title.copyWith(color: c.ink)),
      const SizedBox(height: MiSpace.xs),
      MiRecord(label: 'Judged', value: verdict.reasoning),
      const SizedBox(height: MiSpace.sm),
      Wrap(
        spacing: MiSpace.sm,
        children: <Widget>[
          for (final HarnessTemplate t in harnessTemplates)
            MiButton(
              label: t.name,
              onPressed: () {
                d
                  ..tierId = t.id
                  ..tierReasoning = t.id == d.draftVerdict().templateId
                      ? d.draftVerdict().reasoning
                      : 'Chosen by the client over the '
                            '${templateById(d.draftVerdict().templateId).name} '
                            'the council judged from their appetite.';
                setState(() {});
              },
              kind: t.id != verdict.templateId
                  ? MiButtonKind.secondary
                  : MiButtonKind.primary,
            ),
        ],
      ),
      const SizedBox(height: MiSpace.xs),
      Text(
        templateById(verdict.templateId).expectation,
        style: MiType.caption.copyWith(color: c.inkMuted),
      ),
      const SizedBox(height: MiSpace.xl),
      if (_problem != null) ...<Widget>[
        Text(_problem!, style: MiType.body.copyWith(color: c.warning)),
        const SizedBox(height: MiSpace.md),
      ],
      MiButton(
        label: 'Close the interview and open the sitting',
        busy: _closing,
        onPressed: _closing
            ? null
            : () {
                d.restatement = _brief.text;
                _open();
              },
        kind: MiButtonKind.primary,
      ),
      const SizedBox(height: MiSpace.sm),
      Text(
        'The interview happens once. After this the council does not ask '
        'anything, because there is nobody to ask.',
        style: MiType.caption.copyWith(color: c.inkMuted),
      ),
    ];
  }
}
