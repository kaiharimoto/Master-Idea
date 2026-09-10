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
  paused,
  finished,
  failed,
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
      _phase == SittingPhase.paused;

  /// True when a turn is on screen waiting to be carried.
  bool get needsHand => _hand?.isWaiting ?? false;

  /// Start deliberating [session]. Returns when the sitting ends — dry,
  /// stopped, or failed.
  Future<void> begin(Session session, Settings settings) async {
    if (isBusy) return;
    _events.clear();
    _problem = null;
    _pausedUntil = null;
    _sessionId = session.id;
    _route = canDrive ? SittingRoute.cli : SittingRoute.handover;
    _phase = SittingPhase.deliberating;
    notifyListeners();

    final CouncilTransport? transport = await _transportFor(
      session.id,
      settings,
    );
    if (transport == null) return;

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
      final Session done = await run.deliberate(running);
      await library.save(done);
      _phase = SittingPhase.finished;
      Diagnostics.instance.log(
        'Sitting ${session.id} went dry with ${done.directions.length} '
        'directions.',
      );
    } on CouncilStopped {
      // A stop is a fact about the client, not a diagnosis about the sitting,
      // and nothing needs saving here: every round that closed went to disk
      // through the barrier callback as it closed.
      _phase = SittingPhase.idle;
    } on CouncilUnavailable catch (e) {
      _fail(e.detail);
    } on Object catch (e) {
      _fail('The sitting stopped: $e');
    } finally {
      _pausedUntil = null;
      _hand?.removeListener(_handMoved);
      _hand?.dispose();
      _hand = null;
      _closeTransport();
    }
    notifyListeners();
  }

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
    if (e.kind == 'paused') {
      _pausedUntil = _untilIn(e.detail);
      _phase = SittingPhase.paused;
    } else if (_phase == SittingPhase.paused) {
      _pausedUntil = null;
      _phase = needsHand
          ? SittingPhase.waitingForHand
          : SittingPhase.deliberating;
    }
    notifyListeners();
  }

  /// The resume time out of a pause event, which carries it as an ISO string.
  static DateTime? _untilIn(String detail) {
    final RegExpMatch? m = RegExp(r'until (\S+)').firstMatch(detail);
    if (m == null) return null;
    return DateTime.tryParse(m.group(1)!)?.toLocal();
  }

  void _handMoved() {
    if (_phase == SittingPhase.paused) return;
    _phase = (_hand?.isWaiting ?? false)
        ? SittingPhase.waitingForHand
        : SittingPhase.deliberating;
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
