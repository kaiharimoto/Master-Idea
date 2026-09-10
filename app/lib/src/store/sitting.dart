import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mi_core/mi_core.dart';

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
enum SittingPhase { idle, deliberating, waitingForHand, finished, failed }

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
  Sitting(this.library);

  final Library library;

  SittingPhase _phase = SittingPhase.idle;
  SittingPhase get phase => _phase;

  /// The handover transport, when this sitting is being carried by hand.
  HandoverCouncil? _hand;
  HandoverCouncil? get hand => _hand;

  SittingRoute? _route;
  SittingRoute? get route => _route;

  String? _sessionId;
  String? get sessionId => _sessionId;

  final List<RunEvent> _events = <RunEvent>[];
  List<RunEvent> get events => List<RunEvent>.unmodifiable(_events);

  String? _problem;
  String? get problem => _problem;

  /// True while a sitting is in progress on this device.
  ///
  /// Anything that writes status checks this first. A region that probes on
  /// arrival and writes `idle` while a council is still deliberating is how a
  /// Stop button goes inert and a second Run becomes clickable.
  bool get isBusy =>
      _phase == SittingPhase.deliberating || _phase == SittingPhase.waitingForHand;

  /// True when a turn is on screen waiting to be carried.
  bool get needsHand => _hand?.isWaiting ?? false;

  /// Start deliberating [session]. Returns when the sitting ends — dry,
  /// stopped, or failed.
  Future<void> begin(Session session, Settings settings) async {
    if (isBusy) return;
    _events.clear();
    _problem = null;
    _sessionId = session.id;
    _route = canDriveCouncil ? SittingRoute.cli : SittingRoute.handover;
    _phase = SittingPhase.deliberating;
    notifyListeners();

    CouncilTransport transport;
    try {
      if (_route == SittingRoute.cli) {
        final CouncilSession opened = await openCouncil(
          settings: settings,
          sessionId: session.id,
        );
        transport = opened.council;
      } else {
        final HandoverCouncil hand = HandoverCouncil()..addListener(_handMoved);
        _hand = hand;
        transport = hand;
      }
    } on NoCouncil catch (e) {
      _fail('$e');
      return;
    } on Object catch (e) {
      _fail('The council could not be reached. $e');
      return;
    }

    try {
      final CouncilRun run = CouncilRun(
        transport: transport,
        onEvent: (RunEvent e) {
          _events.add(e);
          // A sitting is quiet by design: territory accumulating, and nothing
          // asking the client to stay. The events are kept so the ledger fills
          // as it happens, not so a log can scroll.
          if (_events.length > 500) _events.removeAt(0);
          notifyListeners();
        },
      );
      final Session done = await run.deliberate(session);
      await library.save(done);
      _phase = SittingPhase.finished;
      Diagnostics.instance.log(
        'Sitting ${session.id} went dry with ${done.directions.length} '
        'directions.',
      );
    } on CouncilPaused catch (e) {
      // A stop is a fact about the client, not a diagnosis about the sitting.
      _phase = SittingPhase.idle;
      _problem = e.kind == 'handover' ? null : 'The provider paused: ${e.detail}';
    } on Object catch (e) {
      _fail('The sitting stopped: $e');
      return;
    } finally {
      _hand?.removeListener(_handMoved);
      _hand = null;
    }
    notifyListeners();
  }

  void _handMoved() {
    _phase = (_hand?.isWaiting ?? false)
        ? SittingPhase.waitingForHand
        : SittingPhase.deliberating;
    notifyListeners();
  }

  /// The client stopped it.
  ///
  /// Only the handover route can be stopped this way; a CLI sitting is stopped
  /// by closing the app, which is guarded. Recorded as a stop rather than as a
  /// failure, because a killed turn is not a diagnosis about the council.
  void stop() {
    _hand?.abandon();
    _phase = SittingPhase.idle;
    notifyListeners();
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
    super.dispose();
  }
}
