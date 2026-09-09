import 'dart:convert';
import 'dart:io';

import 'package:mi_core/mi_core.dart';

/// Sessions on disk, as a directory of plain files.
///
/// Not a database, for the reason Master Prompt gives for the same choice: a
/// session that took six hours of council time should be recoverable with a
/// text editor if this program ever fails to start. The layout is the one the
/// brief fixes, and it is a layout rather than one blob because the parts are
/// written at different moments — the interview freezes at the gate, a round
/// lands at each barrier, a rating lands as each verdict arrives — and a
/// process that dies mid-run should lose the round it was in and nothing else.
///
/// ```
/// sessions/<id>/session.json        title, task id, created, tier
/// sessions/<id>/interview/          the frozen gate: brief, answers, unknowns
/// sessions/<id>/rounds/             one file per round
/// sessions/<id>/ratings/            one file per verdict
/// sessions/<id>/ledger.json         the coverage map
/// sessions/<id>/directions.json     the case file's contents
/// sessions/<id>/assembly.json       what the client selected, and what it becomes
/// sessions/<id>/pitch.md            the export, verbatim as the session made it
/// sessions/<id>/run_manifest.json   machine-written, never hand-edited
/// ```
class SessionStore {
  SessionStore(this.root, {DateTime Function()? now}) : _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  /// The `sessions/` directory itself.
  final Directory root;

  /// Where a new session's id comes from.
  ///
  /// Injected because the bug it guards against only appears on a platform
  /// whose clock is coarse, and the runner these tests run on has a fine one.
  /// Master Prompt lost a mission to exactly this: two ids minted inside one
  /// Windows clock tick collided, and the second session overwrote the first.
  final DateTime Function() _now;

  int _lastMinted = 0;

  Directory _dir(String id) => Directory('${root.path}/$id');

  /// Ids already on disk, so a clock corrected backwards between launches
  /// cannot reissue one.
  void _seedMintFloor() {
    if (!root.existsSync()) return;
    for (final FileSystemEntity e in root.listSync()) {
      if (e is! Directory) continue;
      final int? issued = int.tryParse(
        e.path.split(Platform.pathSeparator).last,
        radix: 36,
      );
      if (issued != null && issued > _lastMinted) _lastMinted = issued;
    }
  }

  String mintId() {
    _seedMintFloor();
    int micros = _now().microsecondsSinceEpoch;
    if (micros <= _lastMinted) micros = _lastMinted + 1;
    _lastMinted = micros;
    return micros.toRadixString(36);
  }

  List<String> listIds() {
    if (!root.existsSync()) return const <String>[];
    return <String>[
      for (final FileSystemEntity e in root.listSync())
        if (e is Directory && File('${e.path}/session.json').existsSync())
          e.path.split(Platform.pathSeparator).last,
    ]..sort();
  }

  bool exists(String id) => File('${_dir(id).path}/session.json').existsSync();

  /// Write the whole session.
  ///
  /// Every file is written to a temporary name and renamed into place, so a
  /// process killed mid-write leaves the previous version rather than half of
  /// the new one. Rounds and ratings are written once and then left alone —
  /// rewriting a round that has already closed would make the stored history
  /// a function of when it was last saved.
  void write(Session s) {
    final Directory dir = _dir(s.id);
    dir.createSync(recursive: true);
    Directory('${dir.path}/interview').createSync(recursive: true);
    Directory('${dir.path}/rounds').createSync(recursive: true);
    Directory('${dir.path}/ratings').createSync(recursive: true);

    _json('${dir.path}/session.json', <String, Object?>{
      'id': s.id,
      'taskId': s.taskId,
      'title': s.title,
      'createdAt': s.createdAt.toIso8601String(),
      'templateId': s.interview.verdict.templateId,
      'profileId': s.interview.profileId,
    });

    // Frozen at the gate. Written once; nothing after the gate may re-elicit
    // an answer, so nothing after the gate rewrites this.
    _json('${dir.path}/interview/record.json', s.interview.toJson());
    File('${dir.path}/interview/brief.md').writeAsStringSync(
      '# The brief, approved verbatim by the client\n\n'
      '${s.interview.brief.restatement}\n\n'
      '_Approved ${s.interview.brief.approvedAt.toIso8601String()}, '
      'hash ${s.interview.brief.hash}._\n',
      flush: true,
    );

    for (final RoundRecord r in s.rounds) {
      final String path =
          '${dir.path}/rounds/round-${r.number.toString().padLeft(3, '0')}.json';
      if (!File(path).existsSync()) _json(path, r.toJson());
    }

    for (final Rating r in s.ratings) {
      final String path =
          '${dir.path}/ratings/${r.directionId}-${r.dimensionId}.json';
      if (!File(path).existsSync()) _json(path, r.toJson());
    }

    _json('${dir.path}/ledger.json', s.ledger.toJson());
    _json('${dir.path}/directions.json', <String, Object?>{
      'directions': s.directions.map((Direction d) => d.toJson()).toList(),
      'challenges': s.challenges.map((Challenge c) => c.toJson()).toList(),
      'assumptions': s.assumptions.map((Assumption a) => a.toJson()).toList(),
    });
    _json('${dir.path}/assembly.json', <String, Object?>{
      'selection': s.selection,
      if (s.integration != null) 'integration': s.integration!.toJson(),
    });
    _json('${dir.path}/run_manifest.json', s.manifest.toJson());

    if (s.pitch.isNotEmpty) {
      File('${dir.path}/pitch.md').writeAsStringSync(s.pitch, flush: true);
    }
  }

  /// Read a session back from its files alone.
  Session read(String id) {
    final Directory dir = _dir(id);
    final Map<String, Object?> index = _readJson('${dir.path}/session.json');
    final InterviewRecord interview = InterviewRecord.fromJson(
      _readJson('${dir.path}/interview/record.json'),
    );

    final List<RoundRecord> rounds = <RoundRecord>[
      for (final File f in _filesIn('${dir.path}/rounds'))
        RoundRecord.fromJson(
          jsonDecode(f.readAsStringSync())! as Map<String, Object?>,
        ),
    ]..sort((RoundRecord a, RoundRecord b) => a.number.compareTo(b.number));

    final List<Rating> ratings = <Rating>[
      for (final File f in _filesIn('${dir.path}/ratings'))
        Rating.fromJson(
          jsonDecode(f.readAsStringSync())! as Map<String, Object?>,
        ),
    ];

    final Map<String, Object?> caseFile = _readJson(
      '${dir.path}/directions.json',
    );
    final Map<String, Object?> assembly = _readJson(
      '${dir.path}/assembly.json',
    );
    final File pitch = File('${dir.path}/pitch.md');

    return Session(
      id: '${index['id']}',
      taskId: '${index['taskId']}',
      title: '${index['title']}',
      createdAt: DateTime.parse('${index['createdAt']}'),
      interview: interview,
      manifest: RunManifest.fromJson(
        _readJson('${dir.path}/run_manifest.json'),
      ),
      ledger: CoverageLedger.fromJson(_readJson('${dir.path}/ledger.json')),
      directions: <Direction>[
        for (final Object? e
            in caseFile['directions'] as List<Object?>? ?? const <Object?>[])
          Direction.fromJson(e! as Map<String, Object?>),
      ],
      challenges: <Challenge>[
        for (final Object? e
            in caseFile['challenges'] as List<Object?>? ?? const <Object?>[])
          Challenge.fromJson(e! as Map<String, Object?>),
      ],
      assumptions: <Assumption>[
        for (final Object? e
            in caseFile['assumptions'] as List<Object?>? ?? const <Object?>[])
          Assumption.fromJson(e! as Map<String, Object?>),
      ],
      ratings: ratings,
      rounds: rounds,
      selection: <String>[
        for (final Object? e
            in assembly['selection'] as List<Object?>? ?? const <Object?>[])
          '$e',
      ],
      integration: assembly['integration'] == null
          ? null
          : Integration.fromJson(
              assembly['integration']! as Map<String, Object?>,
            ),
      pitch: pitch.existsSync() ? pitch.readAsStringSync() : '',
    );
  }

  List<File> _filesIn(String path) {
    final Directory d = Directory(path);
    if (!d.existsSync()) return const <File>[];
    return <File>[
      for (final FileSystemEntity e in d.listSync())
        if (e is File && e.path.endsWith('.json')) e,
    ]..sort((File a, File b) => a.path.compareTo(b.path));
  }

  Map<String, Object?> _readJson(String path) {
    final File f = File(path);
    if (!f.existsSync()) {
      throw StateError('This session is missing $path.');
    }
    return jsonDecode(f.readAsStringSync())! as Map<String, Object?>;
  }

  void _json(String path, Map<String, Object?> value) {
    final File target = File(path);
    final File temp = File('$path.tmp');
    temp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(value),
      flush: true,
    );
    temp.renameSync(target.path);
  }
}
