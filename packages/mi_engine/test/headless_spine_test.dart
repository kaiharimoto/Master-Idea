@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';
import 'dart:io';

import 'package:mi_core/mi_core.dart';
import 'package:test/test.dart';

import 'support/fixtures.dart';

/// The whole headless spine, run as a person would run it: open a session from
/// an interview, deliberate through a CLI, check the invariants, select, and
/// render. Every step goes through `bin/mi.dart` as a real process, because a
/// command whose exit code is wrong is a check that silently always passes,
/// and nothing but running it says otherwise.
void main() {
  late Directory tmp;
  late String fake;
  late String sessions;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('mi-spine');
    fake = '${tmp.path}/fake_council';
    sessions = '${tmp.path}/sessions';
    final ProcessResult r = await Process.run('dart', <String>[
      'compile',
      'exe',
      'tool/fake_council.dart',
      '-o',
      fake,
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
  });

  tearDownAll(() => tmp.deleteSync(recursive: true));

  Future<ProcessResult> mi(List<String> args) =>
      Process.run('dart', <String>['run', 'bin/mi.dart', ...args]);

  test('a session goes from interview to pitch without an interface', () async {
    final File interview = File('${tmp.path}/interview.json')
      ..writeAsStringSync(jsonEncode(referenceInterview().toJson()));

    final ProcessResult opened = await mi(<String>[
      'new',
      sessions,
      interview.path,
    ]);
    expect(opened.exitCode, 0, reason: '${opened.stderr}');
    expect(opened.stdout, contains('Opened'));

    final String id = Directory(sessions)
        .listSync()
        .whereType<Directory>()
        .single
        .path
        .split(Platform.pathSeparator)
        .last;

    final ProcessResult ran = await mi(<String>[
      'run',
      sessions,
      id,
      '--claude',
      fake,
    ]);
    expect(ran.exitCode, 0, reason: '${ran.stderr}');
    expect(ran.stdout, contains('Dry after rounds'));

    final ProcessResult checked = await mi(<String>['check', sessions]);
    expect(checked.exitCode, 0, reason: '${checked.stdout}${checked.stderr}');
    expect(checked.stdout, contains('All three invariants hold'));

    final ProcessResult dossier = await mi(<String>[
      'render',
      sessions,
      id,
      'dossier',
    ]);
    expect(dossier.exitCode, 0);
    expect(dossier.stdout, contains('Traced to'));

    // Nothing may be pitched before the client has chosen.
    final ProcessResult early = await mi(<String>[
      'render',
      sessions,
      id,
      'pitch',
    ]);
    expect(early.exitCode, isNot(0));
    expect(early.stderr, contains('never decides what ships'));

    final Map<String, Object?> caseFile =
        jsonDecode(File('$sessions/$id/directions.json').readAsStringSync())!
            as Map<String, Object?>;
    final String first =
        ((caseFile['directions']! as List<Object?>).first!
                as Map<String, Object?>)['id']!
            as String;

    final ProcessResult selected = await mi(<String>[
      'select',
      sessions,
      id,
      first,
      '--claude',
      fake,
    ]);
    expect(selected.exitCode, 0, reason: '${selected.stderr}');

    final ProcessResult pitch = await mi(<String>[
      'render',
      sessions,
      id,
      'pitch',
    ]);
    expect(pitch.exitCode, 0);
    expect(pitch.stdout, contains('```mi-pitch'));
    expect(PitchPortability.tells('${pitch.stdout}'), isEmpty);
  });

  test('the gate refuses an interview with nothing declared unknown', () async {
    final InterviewRecord record = referenceInterview();
    final Map<String, Object?> broken = record.toJson()
      ..['unknowns'] = <Object?>[];
    final File f = File('${tmp.path}/no-unknowns.json')
      ..writeAsStringSync(jsonEncode(broken));

    final ProcessResult r = await mi(<String>['new', sessions, f.path]);
    expect(r.exitCode, 65);
    expect(
      r.stderr,
      contains('licence'),
      reason:
          'A run with no licence to settle anything stalls the first time it '
          'needs to, and there is nobody there to ask.',
    );
  });
}
