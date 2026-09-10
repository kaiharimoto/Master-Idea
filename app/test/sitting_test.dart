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
