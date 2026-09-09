import '../assembly/integration.dart';
import '../council/angles.dart';
import '../council/dimensions.dart';
import '../council/profiles.dart';
import '../council/roles.dart';
import '../council/templates.dart';
import '../session/direction.dart';
import '../session/ledger.dart';
import '../session/manifest.dart';
import '../session/rating.dart';
import '../session/round.dart';
import '../session/session.dart';
import 'council_prompts.dart';
import 'council_turn.dart';
import 'dedup.dart';
import 'run_clock.dart';

/// Something worth telling a watcher about, without asking them to stay.
///
/// A run is watchable and never waits on input, so these events exist to fill
/// a screen that must stay quiet: territory settled, a round closed, a limit
/// waited out. Deliberately not a progress percentage — nothing here can say
/// how far through a run is, because the run itself does not know until it
/// goes dry.
class RunEvent {
  const RunEvent(this.kind, this.detail, {this.round = 0});

  /// `round-opened`, `angle-returned`, `direction-kept`, `direction-refused`,
  /// `rated`, `territory`, `paused`, `dropped`, `round-closed`, `dry`.
  final String kind;
  final String detail;
  final int round;

  @override
  String toString() =>
      round == 0 ? '$kind: $detail' : '[$round] $kind: $detail';
}

/// The council, deliberating.
///
/// **Rounds are barriers.** Inside a round the angles fan out concurrently and
/// blind to each other, and each direction pipelines through challenge and
/// independent rating the moment it exists rather than waiting for its cohort.
/// The barrier is at the end of the round, where the only question that can
/// stop this run is asked: did anything new come back?
///
/// **There is no step cap, no token ceiling and no timer**, and the absence is
/// deliberate rather than an oversight. A run that can be ended by a counter
/// will be ended by one on a bad day, and 'ran until the cap' would then be
/// recorded as 'ran dry' — which is the failure this whole apparatus exists to
/// prevent. The loop below has exactly one exit: two consecutive rounds at the
/// same breadth that returned nothing new.
class CouncilRun {
  CouncilRun({
    required this.transport,
    this.clock = const SystemClock(),
    this.onEvent,
    this.retriesPerCall = 3,
  });

  final CouncilTransport transport;
  final RunClock clock;
  final void Function(RunEvent)? onEvent;

  /// How many times one call is retried after a provider pause before the run
  /// gives up on it and logs the loss as a dropped territory. Not a run-ending
  /// condition: the round continues without that angle, and the ledger says so.
  final int retriesPerCall;

  final Map<String, int> _seats = <String, int>{};
  int _directionSeq = 0;

  Session? _s;
  Session get _session => _s!;

  void _emit(String kind, String detail, {int round = 0}) =>
      onEvent?.call(RunEvent(kind, detail, round: round));

  AgentInstance _seat(String roleId, int round) {
    final String key = '$roleId:$round';
    final int n = (_seats[key] ?? 0) + 1;
    _seats[key] = n;
    return AgentInstance(roleId: roleId, round: round, ordinal: n);
  }

  /// Run [session] from wherever it is to dryness.
  ///
  /// Resumable: the round number continues from the rounds already stored, so
  /// a run interrupted at hour four picks up at the barrier it reached rather
  /// than starting the deliberation again.
  Future<Session> deliberate(Session session) async {
    _s = session;
    final HarnessTemplate template = session.template;
    final DomainProfile profile = profileById(session.interview.profileId);
    int round = session.rounds.length + 1;
    int quiet = 0;

    while (true) {
      final List<String> angleSet = angleSetFor(
        round: round,
        breadth: template.angleBreadth,
        profile: profile,
      );
      final DateTime started = clock.now();
      _emit('round-opened', 'breadth ${angleSet.length}', round: round);

      final List<DedupRejection> rejections = <DedupRejection>[];
      final List<Refusal> refusals = <Refusal>[];
      final List<String> newIds = <String>[];

      final List<AngleReturn> returns = await Future.wait(<Future<AngleReturn>>[
        for (final String angleId in angleSet)
          _workAngle(
            angleId: angleId,
            round: round,
            profile: profile,
            rejections: rejections,
            refusals: refusals,
            newIds: newIds,
          ),
      ]);

      final List<String> gapsNamed = <String>[];
      if (round % template.roundsPerBarrier == 0) {
        gapsNamed.addAll(await _mapTerritory(round: round, profile: profile));
      }

      _s = _session.copyWith(
        rounds: <RoundRecord>[
          ..._session.rounds,
          RoundRecord(
            number: round,
            angleSet: angleSet,
            returns: returns,
            rejections: rejections,
            refusals: refusals,
            newDirectionIds: newIds,
            gapsNamed: gapsNamed,
            startedAt: started,
            endedAt: clock.now(),
          ),
        ],
      );
      _emit(
        'round-closed',
        newIds.isEmpty
            ? 'nothing new'
            : '${newIds.length} kept, ${rejections.length} already known',
        round: round,
      );

      quiet = newIds.isEmpty ? quiet + 1 : 0;

      // The one exit. Both deciding rounds are named on the record, with their
      // angle sets, so an auditor can check that the second was not narrower
      // than the first — a run declared dry on a narrowed round is a timer
      // with better manners.
      if (quiet >= 2) {
        final RoundRecord second = _session.rounds.last;
        final RoundRecord first = _session.rounds[_session.rounds.length - 2];
        final DrynessDecision decision = DrynessDecision(
          firstRound: first.number,
          secondRound: second.number,
          firstAngleSet: first.angleSet,
          secondAngleSet: second.angleSet,
          dedupRuleId: DedupRule.currentRuleId,
          decidedAt: clock.now(),
          directionCount: _session.directions.length,
          floorAtTier: template.directionFloor,
        );
        _s = _session.copyWith(
          manifest: _session.manifest.closed(clock.now(), decision),
        );
        _emit(
          'dry',
          decision.wentDryBelowFloor
              ? 'dry below the tier floor — re-tier downward rather than '
                    'padding the dossier'
              : 'dry at ${_session.directions.length} directions',
          round: round,
        );
        return _session;
      }

      round++;
    }
  }

  /// One angle's whole working life in a round: search, then judge what it
  /// found, without waiting for any other angle.
  Future<AngleReturn> _workAngle({
    required String angleId,
    required int round,
    required DomainProfile profile,
    required List<DedupRejection> rejections,
    required List<Refusal> refusals,
    required List<String> newIds,
  }) async {
    final AgentInstance prospector = _seat('prospector', round);
    final ExplorationAngle angle = angleById(angleId);
    final String prompt = CouncilPrompts.propose(
      brief: _session.interview.brief,
      profile: profile,
      angle: angle,
      openGaps: _session.ledger.gaps,
      answers: _session.interview.answers,
      wanted: 4,
    );

    final CouncilReply? reply = await _ask(
      CouncilTurn(
        agent: prospector,
        purpose: 'propose',
        prompt: prompt,
        conversation: 'propose-$round-$angleId',
      ),
      onLost: (String why) {
        _dropTerritory(
          id: 'drop-$angleId-r$round',
          name: '${angle.name}, round $round',
          description: angle.modality,
          reason: 'The provider would not complete this search: $why',
          round: round,
        );
      },
    );
    if (reply == null) {
      return AngleReturn(
        angleId: angleId,
        by: prospector.id,
        proposedIds: const <String>[],
        keptIds: const <String>[],
      );
    }

    final ParsedReply parsed = CouncilReplyParser.parse(reply.text);
    final List<String> proposedTitles = <String>[];
    final List<Direction> kept = <Direction>[];

    // Synchronous from here to the end of the accept loop: no `await` may be
    // introduced inside it. Angles run concurrently, and deduplication that
    // yields halfway through lets two angles both accept the same proposal.
    for (final CouncilBlock b in parsed.of('mi-direction')) {
      final String title = b.get('title');
      proposedTitles.add(title);
      final Refusal? bad = _refuse(b, round);
      if (bad != null) {
        refusals.add(bad);
        _emit('direction-refused', '${bad.kind}: $title', round: round);
        continue;
      }
      final String substance = '${b.get('statement')} ${b.get('mechanism')}';
      final DedupVerdict verdict = DedupRule.test(
        substance,
        _session.directions,
      );
      if (verdict.isDuplicate) {
        rejections.add(
          verdict.asRejection(
            candidateTitle: title,
            candidateSubstance: substance,
          ),
        );
        continue;
      }
      final Direction d = _direction(b, round, angleId, prospector.id);
      _s = _session.copyWith(
        directions: <Direction>[..._session.directions, d],
      );
      kept.add(d);
      newIds.add(d.id);
      _emit('direction-kept', d.title, round: round);
    }

    _recordAssumptions(parsed, round, kept);

    // Pipelined: this angle's directions are challenged and rated now, while
    // the other angles are still searching.
    await Future.wait(<Future<void>>[
      for (final Direction d in kept) _judge(d, round),
    ]);

    return AngleReturn(
      angleId: angleId,
      by: prospector.id,
      proposedIds: proposedTitles,
      keptIds: <String>[for (final Direction d in kept) d.id],
    );
  }

  /// Everything that must be true before a proposal may enter the record.
  Refusal? _refuse(CouncilBlock b, int round) {
    final String title = b.get('title');
    if (title.trim().isEmpty || b.get('statement').trim().isEmpty) {
      return Refusal(
        candidateTitle: title.isEmpty ? '(untitled)' : title,
        kind: 'unsourced',
        reason: 'A direction with no statement is not a direction.',
      );
    }
    if (b.get('mechanism').trim().isEmpty) {
      return Refusal(
        candidateTitle: title,
        kind: 'no-mechanism',
        reason:
            'No mechanism was given, which is the consultant-ambition '
            'anti-pattern rather than a missing field.',
      );
    }
    final String? answerId = b.has('trace-answer')
        ? b.get('trace-answer')
        : null;
    final String? gapId = b.has('trace-gap') ? b.get('trace-gap') : null;
    if (answerId == null && gapId == null) {
      return Refusal(
        candidateTitle: title,
        kind: 'unsourced',
        reason: 'Traced to neither an interview answer nor a named gap.',
      );
    }
    if (answerId != null && _session.interview.answerFor(answerId) == null) {
      return Refusal(
        candidateTitle: title,
        kind: 'unsourced',
        reason: 'Cites interview answer "$answerId", which does not exist.',
      );
    }
    if (gapId != null) {
      final Territory? t = _session.ledger.byId(gapId);
      if (t == null) {
        return Refusal(
          candidateTitle: title,
          kind: 'unsourced',
          reason: 'Cites ledger gap "$gapId", which is not on the map.',
        );
      }
      if (t.firstWrittenInRound >= round) {
        return Refusal(
          candidateTitle: title,
          kind: 'gap-not-yet-written',
          reason:
              'Cites a gap first written in round ${t.firstWrittenInRound}, '
              'which is not earlier than this one. A gap named to justify a '
              'direction already written is a rationalisation.',
        );
      }
    }
    return null;
  }

  Direction _direction(
    CouncilBlock b,
    int round,
    String angleId,
    String proposedBy,
  ) {
    _directionSeq++;
    final String clusterName = b.get('cluster', fallback: 'Unclustered');
    return Direction(
      id: 'd-${_directionSeq.toString().padLeft(4, '0')}',
      clusterId: _slug(clusterName),
      clusterName: clusterName,
      ambition: Ambition.values.firstWhere(
        (Ambition a) => a.name == b.get('ambition'),
        orElse: () => Ambition.ambitious,
      ),
      title: b.get('title'),
      statement: b.get('statement'),
      mechanism: b.get('mechanism'),
      proposedBy: proposedBy,
      round: round,
      angleId: angleId,
      trace: TraceLink(
        answerModuleId: b.has('trace-answer') ? b.get('trace-answer') : null,
        gapId: b.has('trace-gap') ? b.get('trace-gap') : null,
        quote: b.get('quote'),
      ),
    );
  }

  void _recordAssumptions(ParsedReply parsed, int round, List<Direction> kept) {
    for (final CouncilBlock b in parsed.of('mi-assumption')) {
      if (!b.has('made')) continue;
      final String unknown = b.get('unknown');
      _s = _session.copyWith(
        assumptions: <Assumption>[
          ..._session.assumptions,
          Assumption(
            id: 'a-${_session.assumptions.length + 1}',
            round: round,
            made: b.get('made'),
            because: b.get('because'),
            affects: <String>[for (final Direction d in kept) d.id],
            answersUnknownId: unknown.isEmpty || unknown == 'none'
                ? null
                : unknown,
          ),
        ],
      );
    }
  }

  /// Challenge, then rate on every dimension, then invite dissent.
  ///
  /// The assessor is a fresh seat for every rating, and no seat that can
  /// propose can rate — so a direction is never judged by its own advocate at
  /// role level or at instance level. The context is built by
  /// [RatingContext.forDirection], which is the only thing that decides what a
  /// rater sees.
  Future<void> _judge(Direction d, int round) async {
    final AgentInstance challenger = _seat('challenger', round);
    final CouncilReply? cr = await _ask(
      CouncilTurn(
        agent: challenger,
        purpose: 'challenge',
        prompt: CouncilPrompts.challenge(brief: _session.interview.brief, d: d),
        conversation: 'challenge-${d.id}',
      ),
    );
    if (cr != null) {
      final ParsedReply p = CouncilReplyParser.parse(cr.text);
      for (final CouncilBlock b in p.of('mi-challenge')) {
        if (!b.has('attack')) continue;
        _s = _session.copyWith(
          challenges: <Challenge>[
            ..._session.challenges,
            Challenge(
              directionId: d.id,
              by: challenger.id,
              attack: b.get('attack'),
              answered: b.get('fatal') != 'yes',
            ),
          ],
        );
      }
    }

    for (final RatingDimension dim in ratingDimensions) {
      final AgentInstance assessor = _seat('assessor', round);
      final RatingContext context = RatingContext.forDirection(
        d,
        dim,
        briefRestatement: _session.interview.brief.restatement,
      );
      final CouncilReply? rr = await _ask(
        CouncilTurn(
          agent: assessor,
          purpose: 'rate',
          prompt: CouncilPrompts.rate(context, dim),
          conversation: 'rate-${d.id}-${dim.id}',
        ),
      );
      if (rr == null) continue;
      final ParsedReply p = CouncilReplyParser.parse(rr.text);
      final List<CouncilBlock> blocks = p.of('mi-rating');
      if (blocks.isEmpty) continue;
      final CouncilBlock b = blocks.first;
      final String verdict = b.get('verdict').toLowerCase().trim();
      if (!dim.vocabulary.contains(verdict)) continue;

      final List<Dissent> dissents = await _inviteDissent(
        d: d,
        dim: dim,
        context: context,
        verdict: verdict,
        because: b.get('because'),
        round: round,
      );

      _s = _session.copyWith(
        ratings: <Rating>[
          ..._session.ratings,
          Rating(
            directionId: d.id,
            dimensionId: dim.id,
            verdict: verdict,
            vocabularyId: dim.vocabulary.id,
            ratedBy: assessor.id,
            context: context,
            because: b.get('because'),
            dissents: dissents,
          ),
        ],
      );
      _emit('rated', '${d.title}: ${dim.name} — $verdict', round: round);
    }
  }

  Future<List<Dissent>> _inviteDissent({
    required Direction d,
    required RatingDimension dim,
    required RatingContext context,
    required String verdict,
    required String because,
    required int round,
  }) async {
    final AgentInstance dissenter = _seat('dissenter', round);
    final CouncilReply? reply = await _ask(
      CouncilTurn(
        agent: dissenter,
        purpose: 'dissent',
        prompt: CouncilPrompts.dissent(context, dim, verdict, because),
        conversation: 'dissent-${d.id}-${dim.id}',
      ),
    );
    if (reply == null) return const <Dissent>[];
    final ParsedReply p = CouncilReplyParser.parse(reply.text);
    return <Dissent>[
      for (final CouncilBlock b in p.of('mi-dissent'))
        if (b.has('verdict') &&
            dim.vocabulary.contains(b.get('verdict').toLowerCase().trim()) &&
            b.get('verdict').toLowerCase().trim() != verdict)
          Dissent(
            by: dissenter.id,
            verdict: b.get('verdict').toLowerCase().trim(),
            because: b.get('because'),
          ),
    ];
  }

  Future<List<String>> _mapTerritory({
    required int round,
    required DomainProfile profile,
  }) async {
    final AgentInstance cartographer = _seat('cartographer', round);
    final CouncilReply? reply = await _ask(
      CouncilTurn(
        agent: cartographer,
        purpose: 'map',
        prompt: CouncilPrompts.mapTerritory(
          brief: _session.interview.brief,
          profile: profile,
          found: _session.directions,
          ledger: _session.ledger,
        ),
        conversation: 'map-$round',
      ),
    );
    if (reply == null) return const <String>[];

    final ParsedReply p = CouncilReplyParser.parse(reply.text);
    final List<String> gaps = <String>[];
    for (final CouncilBlock b in p.of('mi-territory')) {
      if (!b.has('id') || !b.has('name')) continue;
      final TerritoryStatus status = TerritoryStatus.values.firstWhere(
        (TerritoryStatus s) => s.name == b.get('status'),
        orElse: () => TerritoryStatus.gap,
      );
      // A drop with no reason is a silent truncation. The cartographer is not
      // permitted one, so the run supplies the only honest reason available:
      // that none was given.
      final String reason = status == TerritoryStatus.dropped
          ? (b.has('reason')
                ? b.get('reason')
                : 'Dropped without a stated reason at the round $round barrier.')
          : '';
      final Territory t = Territory(
        id: b.get('id'),
        name: b.get('name'),
        description: b.get('description'),
        status: status,
        firstWrittenInRound:
            _session.ledger.byId(b.get('id'))?.firstWrittenInRound ?? round,
        reason: reason,
      );
      _s = _session.copyWith(
        ledger: _session.ledger.byId(t.id) == null
            ? _session.ledger.add(t)
            : _session.ledger.replace(t),
      );
      if (t.isGap) gaps.add(t.id);
      _emit('territory', '${t.name} — ${t.status.name}', round: round);
    }
    return gaps;
  }

  void _dropTerritory({
    required String id,
    required String name,
    required String description,
    required String reason,
    required int round,
  }) {
    _s = _session.copyWith(
      ledger: _session.ledger.add(
        Territory(
          id: id,
          name: name,
          description: description,
          status: TerritoryStatus.dropped,
          firstWrittenInRound: round,
          reason: reason,
        ),
      ),
    );
    _emit('dropped', '$name — $reason', round: round);
  }

  /// One call, with the provider's pauses waited out rather than mistaken for
  /// silence.
  ///
  /// A rate or session limit is logged as a pause, excluded from council time,
  /// and retried. Only when the retries are spent does the call give up — and
  /// giving up loses that search, which is logged as a dropped territory, and
  /// never ends the run.
  Future<CouncilReply?> _ask(
    CouncilTurn turn, {
    void Function(String why)? onLost,
  }) async {
    for (int attempt = 0; attempt <= retriesPerCall; attempt++) {
      try {
        final CouncilReply reply = await transport.ask(turn);
        _s = _session.copyWith(
          manifest: _session.manifest.record(
            ModelCall(
              at: clock.now(),
              purpose: turn.purpose,
              by: turn.agent.id,
              promptChars: turn.prompt.length,
              replyChars: reply.text.length,
              tokensIn: reply.tokensIn,
              tokensOut: reply.tokensOut,
            ),
          ),
        );
        return reply;
      } on CouncilPaused catch (p) {
        final DateTime from = clock.now();
        _emit('paused', '${p.kind} limit until ${p.until.toIso8601String()}');
        await clock.waitUntil(p.until);
        _s = _session.copyWith(
          manifest: _session.manifest.paused(
            LimitPause(
              from: from,
              until: clock.now(),
              kind: p.kind,
              detail: p.detail,
            ),
          ),
        );
      }
    }
    onLost?.call(
      'the provider paused this call more than $retriesPerCall times',
    );
    return null;
  }

  /// The angles seated in a round.
  ///
  /// Rotates through the whole catalog so that every angle is eventually
  /// searched even at the narrowest tier, where breadth is smaller than the
  /// catalog. The profile's favoured angles lead in the opening round and
  /// nowhere else: a medium may say where to start, never where to stop, or a
  /// domain profile becomes a way of quietly narrowing the search.
  ///
  /// Breadth is constant for the life of a run. A dryness decision made on a
  /// narrower round would be a decision made on less looking, which the
  /// invariant suite refuses — keeping breadth fixed makes that impossible
  /// rather than merely checked.
  static List<String> angleSetFor({
    required int round,
    required int breadth,
    required DomainProfile profile,
  }) {
    final List<String> catalog = <String>[
      ...profile.favouredAngles,
      for (final ExplorationAngle a in explorationAngles)
        if (!profile.favouredAngles.contains(a.id)) a.id,
    ];
    final int start = ((round - 1) * breadth) % catalog.length;
    return <String>[
      for (int i = 0; i < breadth; i++) catalog[(start + i) % catalog.length],
    ];
  }

  /// Compute what a selection becomes, for Assembly.
  ///
  /// Lives on the run rather than on the session because it needs the council;
  /// everything the *renderers* need is already on the session, which is what
  /// lets a finished session be reopened with no transport at all.
  Future<Integration?> integrate(Session session, List<String> ids) async {
    _s = session;
    final List<Direction> selected = <Direction>[
      for (final String id in ids)
        if (session.directionById(id) != null) session.directionById(id)!,
    ];
    if (selected.isEmpty) return null;
    final AgentInstance integrator = _seat('integrator', 0);
    final CouncilReply? reply = await _ask(
      CouncilTurn(
        agent: integrator,
        purpose: 'integrate',
        prompt: CouncilPrompts.integrate(
          brief: session.interview.brief,
          selected: selected,
        ),
        conversation: 'integrate',
      ),
    );
    if (reply == null) return null;
    final ParsedReply p = CouncilReplyParser.parse(reply.text);
    final List<CouncilBlock> blocks = p.of('mi-integration');
    if (blocks.isEmpty) return null;
    final CouncilBlock b = blocks.first;

    final List<Interaction> interactions = <Interaction>[
      for (final String line in b.all('reinforces'))
        if (_pair(line) != null) _pair(line)!.copyAs('reinforces'),
      for (final String line in b.all('conflicts'))
        if (_pair(line) != null) _pair(line)!.copyAs('conflicts'),
    ];

    return Integration(
      forSelection: <String>[...ids]..sort(),
      becomes: b.get('becomes'),
      interactions: interactions,
      by: integrator.id,
      computedAt: clock.now(),
    );
  }

  static _Pair? _pair(String line) {
    final List<String> parts = line.split('|');
    if (parts.length < 3) return null;
    return _Pair(
      parts[0].trim(),
      parts[1].trim(),
      parts.sublist(2).join('|').trim(),
    );
  }

  static String _slug(String s) {
    final String base = s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return base.isEmpty ? 'unclustered' : base;
  }
}

class _Pair {
  const _Pair(this.a, this.b, this.why);
  final String a;
  final String b;
  final String why;
  Interaction copyAs(String kind) =>
      Interaction(a: a, b: b, kind: kind, because: why);
}
