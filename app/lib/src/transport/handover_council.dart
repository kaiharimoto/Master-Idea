import 'dart:async';

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
/// A reply is never discarded: whatever arrives is handed to the same parser
/// the CLI transport uses, and a paste that yields nothing is reported as
/// nothing found rather than silently treated as an exhausted angle — the
/// distinction between those two is what dryness means.
class HandoverCouncil extends ChangeNotifier implements CouncilTransport {
  Completer<CouncilReply>? _pending;
  CouncilTurn? _turn;

  /// The turn waiting to be carried, if one is.
  CouncilTurn? get waiting => _turn;

  bool get isWaiting => _turn != null;

  /// How many turns have been carried by hand this sitting. Shown so the
  /// client can see what they are committing to before they start.
  int carried = 0;

  @override
  Future<CouncilReply> ask(CouncilTurn turn) {
    // One at a time. A second turn arriving while one is on screen would
    // strand the first, and the run would wait forever on a reply nobody was
    // ever shown.
    if (_pending != null) {
      return Future<CouncilReply>.error(
        StateError('A turn is already waiting to be carried.'),
      );
    }
    final Completer<CouncilReply> completer = Completer<CouncilReply>();
    _pending = completer;
    _turn = turn;
    notifyListeners();
    return completer.future;
  }

  /// The client brought a reply back.
  void receive(String text) {
    final Completer<CouncilReply>? c = _pending;
    if (c == null) return;
    _pending = null;
    _turn = null;
    carried++;
    notifyListeners();
    // Token counts are unknowable on this route — the chat app does not
    // report them — and are recorded as zero rather than guessed, so a
    // manifest never claims usage that was never measured.
    c.complete(CouncilReply(text: text));
  }

  /// The client stopped. The run sees a pause rather than an empty reply,
  /// because an empty reply is evidence of dryness and this is the opposite of
  /// evidence.
  void abandon() {
    final Completer<CouncilReply>? c = _pending;
    _pending = null;
    _turn = null;
    notifyListeners();
    c?.completeError(
      CouncilPaused(
        'handover',
        'The sitting was stopped by hand.',
        DateTime.now().toUtc(),
      ),
    );
  }

  @override
  void dispose() {
    // Never leave the run holding a future nobody will complete.
    abandon();
    super.dispose();
  }
}
