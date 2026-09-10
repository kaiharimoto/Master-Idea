import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_engine/mi_engine.dart';
import 'package:path_provider/path_provider.dart';

import 'diagnostics.dart';
import 'settings.dart';

/// The session library: everything stored on this device, and the one that is
/// open.
///
/// Sessions are plain files in a directory, written by `mi_engine`'s
/// `SessionStore` — the same layout the headless entry point reads and writes,
/// so a session run from the command line opens here and one run here can be
/// audited from a terminal. Not a database on purpose: a sitting that took six
/// hours of council time should be recoverable with a text editor if this app
/// ever fails to start.
class Library extends ChangeNotifier {
  Library({Directory? root, this.inMemory = false}) : _root = root;

  /// Skip the filesystem entirely.
  ///
  /// Exists for widget tests. Real file I/O cannot complete inside the widget
  /// tester's fake-async zone, so a test that persists either hangs or races
  /// depending on machine load — and a flaky test about the interface is worse
  /// than none, because it teaches you to ignore red.
  final bool inMemory;

  Directory? _root;
  SessionStore? _store;

  final Map<String, Session> _sessions = <String, Session>{};
  final List<String> _order = <String>[];
  String? _openId;
  Settings _settings = const Settings();
  bool _loaded = false;

  bool get isLoaded => _loaded;
  Settings get settings => _settings;

  /// Newest first, which is the order a library is read in.
  List<Session> get sessions => <Session>[
    for (final String id in _order)
      if (_sessions[id] != null) _sessions[id]!,
  ];

  Session? get open => _openId == null ? null : _sessions[_openId];

  bool get isEmpty => _order.isEmpty;

  Future<Directory> _dir() async {
    if (_root == null) {
      final Directory support = await getApplicationSupportDirectory();
      _root = Directory('${support.path}${Platform.pathSeparator}sessions');
    }
    if (!_root!.existsSync()) _root!.createSync(recursive: true);
    return _root!;
  }

  Future<SessionStore> _sessionStore() async =>
      _store ??= SessionStore(await _dir());

  Future<void> load() async {
    if (inMemory) {
      _loaded = true;
      notifyListeners();
      return;
    }
    final SessionStore store = await _sessionStore();
    _sessions.clear();
    _order.clear();
    for (final String id in store.listIds()) {
      try {
        final Session s = store.read(id);
        _sessions[id] = s;
        _order.add(id);
      } on Object catch (e) {
        // One unreadable session must not stop the rest of the library
        // loading. A library that will not open because of one bad file is a
        // library nobody can rescue anything from.
        Diagnostics.instance.log('Skipped an unreadable session $id: $e');
      }
    }
    _order.sort(
      (String a, String b) =>
          _sessions[b]!.createdAt.compareTo(_sessions[a]!.createdAt),
    );

    final File s = File('${_root!.path}${Platform.pathSeparator}settings.json');
    if (s.existsSync()) {
      try {
        final Object? j = jsonDecode(s.readAsStringSync());
        if (j is Map<String, Object?>) _settings = Settings.fromJson(j);
      } on FormatException {
        _settings = const Settings();
      }
    }

    final File d = _draftFile(_root!);
    if (d.existsSync()) {
      try {
        final Object? j = jsonDecode(d.readAsStringSync());
        if (j is Map<String, Object?>) _draft = j;
      } on FormatException {
        // An unreadable draft is not worth refusing to start over.
        _draft = null;
      }
    }

    _loaded = true;
    Diagnostics.instance.log('Loaded ${_order.length} session(s).');
    notifyListeners();
  }

  /// Open a session from a completed interview.
  ///
  /// The gate is checked here and nowhere else: a run does not begin without a
  /// confirmed brief and a declared list of unknowns, because the run never
  /// waits on input and would otherwise stall the first time it needed a
  /// decision, with nobody there to make one.
  Future<Session> begin(InterviewRecord interview) async {
    final List<GateRefusal> refusals = InterviewGate.refusals(interview);
    if (refusals.isNotEmpty) {
      throw StateError(refusals.map((GateRefusal r) => r.reason).join(' '));
    }

    final String id = inMemory
        ? 'mem-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
        : (await _sessionStore()).mintId();
    final String title = SessionTitle.from(interview.brief.restatement);
    final Session session = Session(
      id: id,
      taskId: SessionTitle.slug(title),
      title: title,
      createdAt: DateTime.now().toUtc(),
      interview: interview,
      manifest: RunManifest(
        sessionId: id,
        templateId: interview.verdict.templateId,
        tier: interview.verdict.template.tier,
        transport: 'cli',
        startedAt: DateTime.now().toUtc(),
      ),
    );
    _sessions[id] = session;
    _order.insert(0, id);
    _openId = id;
    await clearDraft();
    Diagnostics.instance.log(
      'Opened session $id at the ${interview.verdict.template.name} tier.',
    );
    await save(session);
    return session;
  }

  /// Record a session as it stands. Called after every barrier, so a run
  /// interrupted at hour four resumes from the round it reached.
  Future<void> save(Session s) async {
    _sessions[s.id] = s;
    if (!_order.contains(s.id)) _order.insert(0, s.id);
    notifyListeners();
    if (inMemory) return;
    (await _sessionStore()).write(s);
  }

  /// Remove a session and everything in it.
  ///
  /// Nothing is hosted anywhere, so this is the only copy — which is why the
  /// screen asks first and says so in those words. The store refuses an id
  /// that is not a session of its own, so a bad one cannot take a directory
  /// with it.
  Future<void> delete(String id) async {
    if (_openId == id) _openId = null;
    _sessions.remove(id);
    _order.remove(id);
    notifyListeners();
    if (inMemory) return;
    (await _sessionStore()).delete(id);
    Diagnostics.instance.log('Deleted session $id.');
  }

  void select(String id) {
    _openId = _sessions.containsKey(id) ? id : null;
    notifyListeners();
  }

  /// Step back to no session, which is what puts the app on its opening
  /// question. The tool always moves first; there is no blank canvas to
  /// return to.
  void close() {
    _openId = null;
    notifyListeners();
  }

  /// Where a session's files are, for the client who wants to look.
  String pathOf(String id) =>
      _root == null ? '' : '${_root!.path}${Platform.pathSeparator}$id';

  /// Where the library itself is. Not the newest session's own directory,
  /// which is what "Kept in" used to show.
  String get root => _root?.path ?? '';

  /// The interview in progress, if one is.
  ///
  /// An interview is fifteen questions of the client's own words and the one
  /// stage where all of their work happens. It lived in a widget's state: a
  /// phone reclaiming the app in the background lost every answer, with
  /// nothing on disk and nothing to resume. It is a **draft** and not a
  /// record — nothing here has been through the gate — so it lives beside the
  /// settings rather than among the sessions, and it is deleted the moment
  /// the gate closes over it.
  Map<String, Object?>? _draft;

  Map<String, Object?>? get draft => _draft;

  Future<void> saveDraft(Map<String, Object?> d) async {
    _draft = d;
    if (inMemory) return;
    final Directory dir = await _dir();
    _draftFile(dir).writeAsStringSync(jsonEncode(d), flush: true);
  }

  Future<void> clearDraft() async {
    _draft = null;
    notifyListeners();
    if (inMemory) return;
    final File f = _draftFile(await _dir());
    if (f.existsSync()) f.deleteSync();
  }

  File _draftFile(Directory dir) =>
      File('${dir.path}${Platform.pathSeparator}draft.json');

  Future<void> updateSettings(Settings s) async {
    _settings = s;
    notifyListeners();
    if (inMemory) return;
    final Directory dir = await _dir();
    File('${dir.path}${Platform.pathSeparator}settings.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(s.toJson()),
      flush: true,
    );
  }
}
