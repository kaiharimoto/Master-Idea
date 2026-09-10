import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:mi_core/mi_core.dart';

/// The council reached by hand, one turn at a time.
///
/// This is the phone's transport. There is no CLI on a phone, so a turn leaves
/// as text the client pastes into a chat and comes back as text they paste
/// here — and the same `CouncilRun` drives it, so a sitting conducted this way
/// produces exactly the same records, invariants and dossier as one driven
/// down a pipe.
///
/// **It is never unattended, and must never be presented as if it were.** A
/// six-hour sitting on this transport is six hours of a person copying, which
/// is why the phone runs the smallest tier and the app says so plainly rather
/// than borrowing the desktop's autonomy.
///
/// **Turns queue; they are never refused.** A round fans out four angles at
/// the smallest tier and pipelines every direction through challenge and
/// rating, so the second turn arrives while the first is still on screen.
/// Answering it with an error was not a limitation of the phone but the end of
/// the sitting: the error is not a pause, so it left the run, and the client
/// lost the turn they had just carried by hand. One queue, served in order,
/// keeps the same `CouncilRun` and the same breadth — the transport decides
/// how a turn travels, never how wide the council looks.
///
/// A reply is never discarded: whatever arrives is handed to the same parser
/// the CLI transport uses, and a paste that yields nothing is reported as
/// nothing found rather than silently treated as an exhausted angle — the
/// distinction between those two is what dryness means.
class HandoverCouncil extends ChangeNotifier implements CouncilTransport {
  final Queue<_Carried> _pending = Queue<_Carried>();
  bool _stopped = false;

  /// The turn waiting to be carried, if one is.
  CouncilTurn? get waiting => _pending.isEmpty ? null : _pending.first.turn;

  bool get isWaiting => _pending.isNotEmpty;

  /// How many turns are queued behind the one on screen.
  ///
  /// Shown rather than hidden: a client carrying turns by hand is entitled to
  /// know how many are behind this one before they start.
  int get queued => _pending.isEmpty ? 0 : _pending.length - 1;

  /// How many turns have been carried by hand this sitting.
  int carried = 0;

  @override
  Future<CouncilReply> ask(CouncilTurn turn) {
    if (_stopped) {
      return Future<CouncilReply>.error(CouncilStopped(DateTime.now().toUtc()));
    }
    final _Carried held = _Carried(turn, Completer<CouncilReply>());
    _pending.add(held);
    notifyListeners();
    return held.completer.future;
  }

  /// The client brought a reply back for the turn on screen.
  void receive(String text) {
    if (_pending.isEmpty) return;
    final _Carried done = _pending.removeFirst();
    carried++;
    notifyListeners();
    // Token counts are unknowable on this route — the chat app does not
    // report them — and are recorded as zero rather than guessed, so a
    // manifest never claims usage that was never measured.
    done.completer.complete(CouncilReply(text: text));
  }

  /// The client stopped.
  ///
  /// Every queued turn fails with [CouncilStopped] and every later one is
  /// refused, so the run ends where it stands rather than putting the next
  /// turn back on screen. Not an empty reply and not a pause: an empty reply
  /// is evidence of dryness, a pause is waited out and retried, and this is
  /// neither.
  void stop() {
    _stopped = true;
    final DateTime at = DateTime.now().toUtc();
    while (_pending.isNotEmpty) {
      _pending.removeFirst().completer.completeError(CouncilStopped(at));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // Never leave the run holding a future nobody will complete.
    if (!_stopped) stop();
    super.dispose();
  }
}

class _Carried {
  _Carried(this.turn, this.completer);
  final CouncilTurn turn;
  final Completer<CouncilReply> completer;
}
