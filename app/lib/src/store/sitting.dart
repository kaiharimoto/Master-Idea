import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_engine/mi_engine.dart';

import '../transport/council_session.dart';
import '../transport/handover_council.dart';
import 'diagnostics.dart';
import 'library.dart';
import 'settings.dart';

/// Which route a sitting is taking.
enum SittingRoute {
  /// Driven down a pipe to the Claude CLI. Unattended: the client may watch
  /// and may leave.
  cli,

  /// Carried by hand, one turn at a time. Never unattended.
  handover,
}

/// What a sitting is doing.
enum SittingPhase {
  idle,
  deliberating,
  waitingForHand,

  /// Waiting out a provider limit. The provider's, not the client's.
  paused,

  /// Held by the client. Nothing new goes out until they say so.
  held,
  finished,
  failed,
}

/// Where the round in progress has got to, counted from the run's events.
///
/// Counts of things that have happened, never a fraction of a total: the
/// angles seated are known, and so are the directions kept so far, but how
/// many more will be kept is what the round exists to find out.
@immutable
class RoundProgress {
  const RoundProgress({
    required this.round,
    required this.breadth,
    this.anglesBack = 0,
    this.exhausted = 0,
    this.kept = 0,
    this.judged = 0,
    this.calls = 0,
  });

  final int round;

  /// Angles seated this round.
  final int breadth;

  /// Angles that have returned, exhausted or not.
  final int anglesBack;

  /// Of those, the ones that said their angle had nothing left.
  final int exhausted;

  /// Directions accepted this round so far.
  final int kept;

  /// Of those, the ones fully challenged and rated.
  final int judged;

  /// Model calls completed this round.
  final int calls;

  RoundProgress copyWith({
    int? anglesBack,
    int? exhausted,
    int? kept,
    int? judged,
    int? calls,
  }) => RoundProgress(
    round: round,
    breadth: breadth,
    anglesBack: anglesBack ?? this.anglesBack,
    exhausted: exhausted ?? this.exhausted,
    kept: kept ?? this.kept,
    judged: judged ?? this.judged,
    calls: calls ?? this.calls,
  );
}

/// How a transport is opened. Injected only so a widget test can drive a whole
/// sitting without a process; the app always passes the real one.
typedef CouncilOpener =
    Future<CouncilTransport> Function(Settings settings, String sessionId);

/// The council, sitting.
///
/// **There is one of these for the whole app**, hoisted into the home screen
/// and handed to every region that needs it. Two would be free to disagree
/// about whether a sitting is live — and a second Run button that believes
/// nothing is running launches a second council into the same session, which
/// is how a stored session ends up with two rounds numbered four.
///
/// Nothing here decides anything about the deliberation. `CouncilRun` owns the
/// barriers, the dryness decision and the invariants; this owns the fact that
/// a run is in progress, the events worth showing, and getting the result onto
/// disk at every barrier so an interrupted sitting resumes rather than
/// restarting.
class Sitting extends ChangeNotifier {
  Sitting(this.library, {CouncilOpener? open, bool? canDrive})
    : _open = open ?? _openTheRealOne,
      canDrive = canDrive ?? canDriveCouncil;

  static Future<CouncilTransport> _openTheRealOne(
    Settings settings,
    String sessionId,
  ) async =>
      (await openCouncil(settings: settings, sessionId: sessionId)).council;

  final Library library;
  final CouncilOpener _open;

  /// Whether this device can drive a council on its own. A platform question,
  /// never a layout one.
  final bool canDrive;

  SittingPhase _phase = SittingPhase.idle;
  SittingPhase get phase => _phase;

  /// The handover transport, when this sitting is being carried by hand.
  HandoverCouncil? _hand;
  HandoverCouncil? get hand => _hand;

  /// The live transport, kept so that a stop can actually reach it.
  CouncilTransport? _transport;

  /// The run itself, while one is deliberating. Kept so a hold can reach it
  /// and so the screen can read the session as the run has it — the stored
  /// copy moves only at barriers, and a round at the largest tier is an hour
  /// of nothing moving on a screen that is supposed to be watchable.
  CouncilRun? _run;

  /// The session as the run has it right now, round in progress included.
  /// Null when nothing is deliberating.
  Session? get live => _run?.sessionSoFar;

  /// Turns out with the council at this instant, by purpose.
  Map<String, int> get inFlight => _run?.inFlight ?? const <String, int>{};

  RoundProgress? _progress;

  /// The round in progress, as far as it has got.
  RoundProgress? get progress => _progress;

  bool get isHeld => _phase == SittingPhase.held;

  SittingRoute? _route;
  SittingRoute? get route => _route;

  String? _sessionId;
  String? get sessionId => _sessionId;

  final List<RunEvent> _events = <RunEvent>[];
  List<RunEvent> get events => List<RunEvent>.unmodifiable(_events);

  RunEvent? get lastEvent => _events.isEmpty ? null : _events.last;

  String? _problem;
  String? get problem => _problem;

  /// When the provider's limit is expected to lift, while one is being waited
  /// out. A run stalled for an hour with a screen that says "deliberating" is
  /// indistinguishable from a hung app.
  DateTime? _pausedUntil;
  DateTime? get pausedUntil => _pausedUntil;

  /// True while a sitting is in progress on this device.
  ///
  /// Anything that writes status checks this first. A region that probes on
  /// arrival and writes `idle` while a council is still deliberating is how a
  /// Stop button goes inert and a second Run becomes clickable.
  bool get isBusy =>
      _phase == SittingPhase.deliberating ||
      _phase == SittingPhase.waitingForHand ||
      _phase == SittingPhase.paused ||
      _phase == SittingPhase.held;

  /// True when a turn is on screen waiting to be carried.
  bool get needsHand => _hand?.isWaiting ?? false;

  /// Start deliberating [session]. Returns when the sitting ends — dry,
  /// stopped, or failed.
  Future<void> begin(Session session, Settings settings) async {
    if (isBusy) return;
    _events.clear();
    _problem = null;
    _pausedUntil = null;
    _progress = null;
    _sessionId = session.id;
    _route = canDrive ? SittingRoute.cli : SittingRoute.handover;
    _phase = SittingPhase.deliberating;
    notifyListeners();

    final CouncilTransport? transport = await _transportFor(
      session.id,
      settings,
    );
    if (transport == null) return;

    // Everything a report needs to say what this sitting was, in one line,
    // before anything can go wrong. The diagnostic log used to hold nothing
    // between "Started" and the failure — forty minutes of sitting with no
    // account of its tier, breadth, route or model.
    Diagnostics.instance.log(
      'Opened sitting ${session.id} at tier ${session.template.name}: '
      'breadth ${session.template.angleBreadth}, resuming at round '
      '${session.rounds.length + 1}, route ${_route!.name}'
      '${_route == SittingRoute.cli ? ', model ${settings.model.trim().isEmpty ? 'default' : settings.model.trim()}, ${settings.concurrentTurns} concurrent turns' : ''}.',
    );

    // Recorded when the sitting opens rather than when the session did,
    // because the route is a fact about the device this run happened on — and
    // a hand-carried session whose manifest says `cli` is claiming six hours
    // of autonomy no phone has.
    Session running = session.copyWith(
      manifest: session.manifest.onTransport(_route!.name),
    );
    await library.save(running);

    try {
      final CouncilRun run = CouncilRun(
        transport: transport,
        onEvent: _record,
        // Every barrier. A sitting saved only when it finishes is a sitting
        // that loses six hours to a power cut, and the Resume button below is
        // a promise nothing keeps.
        onBarrier: (Session s) async {
          running = s;
          await library.save(s);
        },
      );
      _run = run;
      final Session done = await run.deliberate(running);
      await library.save(done);
      _phase = SittingPhase.finished;
      Diagnostics.instance.log(
        'Sitting ${session.id} went dry with ${done.directions.length} '
        'directions after ${done.manifest.calls.length} model calls.',
      );
    } on CouncilStopped {
      // A stop is a fact about the client, not a diagnosis about the sitting,
      // and nothing needs saving here: every round that closed went to disk
      // through the barrier callback as it closed.
      _phase = SittingPhase.idle;
      Diagnostics.instance.log(
        'Sitting ${session.id} stopped by the client with '
        '${running.rounds.length} round(s) stored.',
      );
    } on CouncilUnavailable catch (e) {
      _fail(e.detail);
    } on Object catch (e) {
      _fail('The sitting stopped: $e');
    } finally {
      _pausedUntil = null;
      _run = null;
      _hand?.removeListener(_handMoved);
      _hand?.dispose();
      _hand = null;
      _closeTransport();
    }
    notifyListeners();
  }

  /// Hold the sitting where it is. Nothing new goes to the council; the turns
  /// already out come back and are kept. [release] lets it continue.
  ///
  /// The client's pause, as distinct from the provider's: a limit is waited
  /// out by the run on its own, and this is waited out by the client. Neither
  /// is a stop, and neither reaches the dryness decision.
  void hold() => _run?.hold();

  /// Let a held sitting continue from exactly where it was.
  void release() => _run?.release();

  /// Compute what a selection becomes together.
  ///
  /// Here rather than in the Assembly screen because it needs a transport, and
  /// on a phone that transport is the hand-carried one — which is the whole
  /// difference between a client who can reach a pitch and one whose session
  /// ends at the dossier.
  Future<Integration?> integrate(
    Session session,
    List<String> ids,
    Settings settings,
  ) async {
    if (isBusy) return null;
    if (ids.isEmpty) return null;
    _problem = null;
    _sessionId = session.id;
    _route = canDrive ? SittingRoute.cli : SittingRoute.handover;
    _phase = SittingPhase.deliberating;
    notifyListeners();

    final CouncilTransport? transport = await _transportFor(
      session.id,
      settings,
    );
    if (transport == null) return null;

    try {
      final Integration? integration = await CouncilRun(
        transport: transport,
        onEvent: _record,
      ).integrate(session, ids);
      _phase = SittingPhase.idle;
      return integration;
    } on CouncilStopped {
      _phase = SittingPhase.idle;
      return null;
    } on CouncilUnavailable catch (e) {
      _fail(e.detail);
      return null;
    } on Object catch (e) {
      _fail('The integration could not be computed. $e');
      return null;
    } finally {
      _hand?.removeListener(_handMoved);
      _hand?.dispose();
      _hand = null;
      _closeTransport();
      notifyListeners();
    }
  }

  /// Ask the clerk for a draft brief and a scale verdict.
  ///
  /// The one council turn that happens before a session exists, so it opens a
  /// transport of its own against a scratch name. On a phone it is carried by
  /// hand like every other turn — one turn, before the client has agreed to
  /// carry hundreds.
  Future<InterviewAdvice?> counsel({
    required List<InterviewAnswer> answers,
    required String profileId,
    required Settings settings,
  }) async {
    if (isBusy) return null;
    _problem = null;
    _route = canDrive ? SittingRoute.cli : SittingRoute.handover;
    _phase = SittingPhase.deliberating;
    notifyListeners();

    final CouncilTransport? transport = await _transportFor(
      'interview',
      settings,
    );
    if (transport == null) return null;

    try {
      return await InterviewCounsel.seek(
        transport: transport,
        answers: answers,
        profileId: profileId,
      );
    } on CouncilStopped {
      return null;
    } on CouncilUnavailable catch (e) {
      _fail(e.detail);
      return null;
    } on Object catch (e) {
      _fail('The clerk could not be reached. $e');
      return null;
    } finally {
      if (_phase != SittingPhase.failed) _phase = SittingPhase.idle;
      _hand?.removeListener(_handMoved);
      _hand?.dispose();
      _hand = null;
      _closeTransport();
      notifyListeners();
    }
  }

  Future<CouncilTransport?> _transportFor(
    String sessionId,
    Settings settings,
  ) async {
    try {
      if (_route == SittingRoute.cli) {
        _transport = await _open(settings, sessionId);
      } else {
        final HandoverCouncil hand = HandoverCouncil()..addListener(_handMoved);
        _hand = hand;
        _transport = hand;
      }
      return _transport;
    } on NoCouncil catch (e) {
      _fail('$e');
      return null;
    } on Object catch (e) {
      _fail('The council could not be reached. $e');
      return null;
    }
  }

  void _record(RunEvent e) {
    _events.add(e);
    // A sitting is quiet by design: territory accumulating, and nothing
    // asking the client to stay. The events are kept so the ledger fills
    // as it happens, not so a log can scroll.
    if (_events.length > 500) _events.removeAt(0);

    _count(e);

    // The lines a report afterwards needs: the shape of every round, and
    // every time the sitting was not deliberating and why. Not every turn —
    // a round is hundreds of them, and a ring of four hundred lines would
    // hold twenty minutes of a six-hour sitting.
    switch (e.kind) {
      case 'round-opened' ||
          'round-closed' ||
          'paused' ||
          'held' ||
          'released' ||
          'dry':
        Diagnostics.instance.log('$e');
      default:
        break;
    }

    if (e.kind == 'paused') {
      _pausedUntil = _untilIn(e.detail);
    } else if (_pausedUntil != null &&
        !DateTime.now().isBefore(_pausedUntil!)) {
      // Cleared by the clock, not by the next event. Turns already out when
      // the limit hit still come back, and one of them returning is not the
      // limit lifting.
      _pausedUntil = null;
    }
    _settle();
    notifyListeners();
  }

  /// The phase, derived from what is true rather than from the last event.
  void _settle() {
    if (!isBusy) return;
    if (_run?.isHeld ?? false) {
      _phase = SittingPhase.held;
    } else if (_pausedUntil != null) {
      _phase = SittingPhase.paused;
    } else {
      _phase = needsHand
          ? SittingPhase.waitingForHand
          : SittingPhase.deliberating;
    }
  }

  void _count(RunEvent e) {
    if (e.kind == 'round-opened') {
      _progress = RoundProgress(
        round: e.round,
        breadth: live?.template.angleBreadth ?? 0,
      );
      return;
    }
    final RoundProgress? p = _progress;
    if (p == null || e.round != p.round) return;
    _progress = switch (e.kind) {
      'angle-returned' => p.copyWith(anglesBack: p.anglesBack + 1),
      'angle-exhausted' => p.copyWith(
        anglesBack: p.anglesBack + 1,
        exhausted: p.exhausted + 1,
      ),
      'direction-kept' => p.copyWith(kept: p.kept + 1),
      'judged' => p.copyWith(judged: p.judged + 1),
      'turn' => p.copyWith(calls: p.calls + 1),
      _ => p,
    };
  }

  /// The resume time out of a pause event, which carries it as an ISO string.
  static DateTime? _untilIn(String detail) {
    final RegExpMatch? m = RegExp(r'until (\S+)').firstMatch(detail);
    if (m == null) return null;
    return DateTime.tryParse(m.group(1)!)?.toLocal();
  }

  void _handMoved() {
    _settle();
    notifyListeners();
  }

  /// The client stopped it.
  ///
  /// Both routes, because a sitting nobody can stop is one whose only exit is
  /// closing the app. Recorded as a stop rather than as a failure: a killed
  /// turn is not a diagnosis about the council, and every round that closed is
  /// already on disk.
  void stop() {
    _hand?.stop();
    _closeTransport();
    _phase = SittingPhase.idle;
    _pausedUntil = null;
    // A held run has turns waiting at its gate. Released after the transport
    // is closed, they reach it and are refused as stopped, which is how the
    // run ends — left held, they would wait on a completer nobody completes.
    _run?.release();
    notifyListeners();
  }

  void _closeTransport() {
    final CouncilTransport? t = _transport;
    if (t is CliCouncil) t.cancel();
    _transport = null;
  }

  void _fail(String why) {
    _problem = why;
    _phase = SittingPhase.failed;
    Diagnostics.instance.log(why);
    notifyListeners();
  }

  @override
  void dispose() {
    _hand?.removeListener(_handMoved);
    _hand?.dispose();
    _closeTransport();
    super.dispose();
  }
}
