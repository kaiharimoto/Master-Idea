import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/store/library.dart';
import 'package:master_idea/src/store/sitting.dart';
import 'package:mi_core/mi_core.dart';

import 'library_test.dart' show interview;
import 'support/scripted_council.dart';

/// What a sitting leaves behind.
///
/// Plain `test`, not `testWidgets`: the library is in memory for the reason
/// the class comment gives, and none of this is about a widget.
void main() {
  Future<(Library, Sitting, Session)> opened({
    ScriptedCouncil? council,
    bool canDrive = true,
  }) async {
    final Library library = Library(inMemory: true);
    await library.load();
    final Session session = await library.begin(interview());
    final Sitting sitting = Sitting(
      library,
      canDrive: canDrive,
      open: (_, _) async => council ?? ScriptedCouncil(),
    );
    return (library, sitting, session);
  }

  test('the session on disk grows as each round closes', () async {
    final (Library library, Sitting sitting, Session session) = await opened();
    final List<int> asStored = <int>[];
    library.addListener(() => asStored.add(library.open!.rounds.length));

    await sitting.begin(session, library.settings);

    expect(sitting.phase, SittingPhase.finished);
    expect(
      asStored.where((int n) => n == 1),
      isNotEmpty,
      reason:
          'A sitting saved only when it finishes loses six hours to a power '
          'cut, and the Resume button is a promise nothing keeps.',
    );
    expect(library.open!.manifest.dryness, isNotNull);
  });

  test('the manifest names the route the sitting actually took', () async {
    final (Library library, Sitting sitting, Session session) = await opened(
      canDrive: false,
      council: ScriptedCouncil(),
    );
    // The handover route needs a hand; this test only cares what was recorded
    // before the first turn went out, so it starts the sitting and stops it.
    unawaited(sitting.begin(session, library.settings));
    await Future<void>.delayed(Duration.zero);

    expect(
      library.open!.manifest.transport,
      'handover',
      reason:
          'A hand-carried session whose manifest says cli is claiming six '
          'hours of autonomy no phone has.',
    );
    sitting.stop();
  });

  test('a paused sitting sends nothing new, and continues whole', () async {
    late final Sitting sitting;
    final ScriptedCouncil council = ScriptedCouncil(
      onCall: (int n) {
        if (n == 2) sitting.hold();
      },
    );
    final Library library = Library(inMemory: true);
    await library.load();
    final Session session = await library.begin(interview());
    sitting = Sitting(library, canDrive: true, open: (_, _) async => council);

    final Future<void> running = sitting.begin(session, library.settings);
    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(sitting.phase, SittingPhase.held);
    expect(sitting.isBusy, isTrue, reason: 'Paused is not stopped.');
    expect(
      council.calls,
      2,
      reason:
          'Every angle behind the one that paused waits at the gate; the '
          'transport must not see them.',
    );
    expect(
      sitting.live,
      isNotNull,
      reason: 'The screen reads the round in progress from the run.',
    );

    sitting.release();
    await running;

    expect(sitting.phase, SittingPhase.finished);
    expect(library.open!.manifest.holds, hasLength(1));
    expect(
      library.open!.manifest.dryness,
      isNotNull,
      reason: 'A pause defers the round; it must not end the run.',
    );
  });

  test(
    'stopping a paused sitting ends it rather than leaving it held',
    () async {
      late final Sitting sitting;
      // The real CLI transport refuses every turn once cancelled; this
      // double stands in for that on the third call, which is the first one
      // the gate lets through after the stop releases it.
      final ScriptedCouncil council = ScriptedCouncil(
        stopOnCall: 3,
        onCall: (int n) {
          if (n == 2) sitting.hold();
        },
      );
      final Library library = Library(inMemory: true);
      await library.load();
      final Session session = await library.begin(interview());
      sitting = Sitting(library, canDrive: true, open: (_, _) async => council);

      final Future<void> running = sitting.begin(session, library.settings);
      for (int i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(sitting.phase, SittingPhase.held);

      sitting.stop();
      await running.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail(
          'The turns waiting at the gate were left waiting on a completer '
          'nobody completes, so the sitting never ended.',
        ),
      );
      expect(sitting.phase, SittingPhase.idle);
    },
  );

  test('a failure that is not a limit is reported, not waited out', () async {
    final (Library library, Sitting sitting, Session session) = await opened(
      council: ScriptedCouncil(failOnCall: 1),
    );

    await sitting.begin(session, library.settings);

    expect(sitting.phase, SittingPhase.failed);
    expect(sitting.problem, contains('not logged in'));
    expect(sitting.isBusy, isFalse);
  });

  test(
    'stopping a hand-carried sitting ends it and keeps the rounds',
    () async {
      final (Library library, Sitting sitting, Session session) = await opened(
        canDrive: false,
      );

      final Future<void> running = sitting.begin(session, library.settings);
      await Future<void>.delayed(Duration.zero);
      expect(sitting.needsHand, isTrue);

      sitting.stop();
      await running;

      expect(sitting.phase, SittingPhase.idle);
      expect(
        sitting.hand,
        isNull,
        reason: 'A stopped sitting must not leave a turn on screen.',
      );
      expect(library.open, isNotNull);
    },
  );
}
