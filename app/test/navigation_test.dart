import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:master_idea/src/app.dart';
import 'package:master_idea/src/store/library.dart';

import 'library_test.dart' show interview;
import 'offline_updater.dart';

/// Getting from one idea to the next, and back out of a region.
///
/// Both were dead ends: the arrival screen appears only when no session is
/// open, nothing ever closed one, and the system back gesture left the
/// application from anywhere because regions are state rather than routes.
void main() {
  /// The system back gesture, as the platform actually delivers it: a
  /// `popRoute` message on the navigation channel, not a key press.
  Future<void> back() async {
    final ByteData message = const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    );
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage('flutter/navigation', message, (ByteData? _) {});
  }

  Future<Library> withOneSession() async {
    final Library library = Library(inMemory: true);
    await library.load();
    await library.begin(interview());
    return library;
  }

  testWidgets('a second idea can be convened without restarting the app', (
    WidgetTester tester,
  ) async {
    final Library library = await withOneSession();
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pump();
    expect(find.text('What is the idea?'), findsNothing);

    await tester.tap(find.text('Put a new idea before the council'));
    await tester.pumpAndSettle();

    expect(
      find.text('What is the idea?'),
      findsOneWidget,
      reason:
          'The tool moves first, and it has to be able to move a second time.',
    );
    expect(library.open, isNull);
    expect(
      library.sessions,
      hasLength(1),
      reason: 'Closing a session is not deleting it.',
    );
  });

  testWidgets('back steps through the regions before leaving anything', (
    WidgetTester tester,
  ) async {
    final Library library = await withOneSession();
    await tester.pumpWidget(
      MasterIdeaApp(library: library, updater: offlineUpdater()),
    );
    await tester.pump();

    // Narrow: the rail is a sheet, and the region is state.
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('Dossier'),
      find.byType(ListView).last,
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dossier').last);
    await tester.pumpAndSettle();
    expect(find.text('Dossier'), findsWidgets);

    await back();
    await tester.pumpAndSettle();
    expect(
      find.text('Interview'),
      findsWidgets,
      reason:
          'Back on a region used to leave the application, mid-sitting, with '
          'no confirmation of any kind.',
    );
    expect(library.open, isNotNull);

    await back();
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Close this session?'),
      findsOneWidget,
      reason: 'The last step out is a question, not an exit.',
    );
  });
}
