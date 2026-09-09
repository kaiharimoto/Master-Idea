import 'package:mi_engine/mi_engine.dart';
import 'package:test/test.dart';

void main() {
  group('finding the binary', () {
    test('a .cmd goes through a shell, and only on Windows', () {
      expect(
        ClaudeCli(
          onWindows: true,
        ).needsShell(r'C:\Users\x\AppData\npm\claude.cmd'),
        isTrue,
        reason:
            'CreateProcess refuses a .cmd outright, and an npm install — the '
            'likeliest install on Windows — puts exactly that on the path.',
      );
      expect(
        ClaudeCli(onWindows: true).needsShell(r'C:\tools\claude.exe'),
        isFalse,
      );
      expect(
        ClaudeCli(onWindows: false).needsShell('/usr/local/bin/claude.cmd'),
        isFalse,
      );
    });

    test('a path that is not a CLI is reported, not skipped', () async {
      final ClaudeCli cli = ClaudeCli(explicitPath: '/nowhere/claude');
      expect(await cli.locate(), isNull);
      expect(cli.attempts, hasLength(1));
      expect(cli.attempts.single.path, '/nowhere/claude');
      expect(cli.attempts.single.usable, isFalse);
      expect(
        cli.attempts.single.detail,
        isNotEmpty,
        reason:
            '"Not installed" is the answer people act on, so every candidate '
            'reports what actually happened rather than just a verdict.',
      );
    });

    test('an explicit path is used alone', () async {
      final ClaudeCli cli = ClaudeCli(explicitPath: '/nowhere/claude');
      await cli.locate();
      expect(
        cli.attempts.map((ProbeOutcome o) => o.path),
        <String>['/nowhere/claude'],
        reason:
            'An explicit path is a directive. A wrong one must be reported '
            'as wrong rather than silently bypassed by a working install '
            'somewhere else, or the settings field appears to do nothing.',
      );
    });
  });
}
