import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../app.dart';
import '../store/library.dart';
import '../store/sitting.dart';
import '../update/updater.dart';
import 'arrival.dart';
import 'assembly.dart';
import 'dossier.dart';
import 'interview.dart';
import 'ledger.dart';
import 'library_screen.dart';
import 'pitch.dart';
import 'run.dart';
import 'settings_screen.dart';
import 'update_sheet.dart';

/// The seven regions a session passes through, plus the two that are about the
/// app rather than about a session.
enum Region {
  interview('Interview'),
  run('Sitting'),
  ledger('Coverage ledger'),
  dossier('Dossier'),
  assembly('Assembly'),
  pitch('Pitch'),
  library('Sessions'),
  settings('Settings');

  const Region(this.title);
  final String title;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.library, required this.updater, super.key});

  final Library library;
  final Updater updater;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// One council sitting for the whole app. Two would be free to disagree
  /// about whether one is live.
  late final Sitting _sitting = Sitting(widget.library);

  Region _region = Region.interview;
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    // Closing the window mid-sitting was a one-click unconfirmed kill: the
    // Windows embedder consumes the first WM_CLOSE precisely so the framework
    // can answer, but only when something has registered for this.
    _lifecycle = AppLifecycleListener(onExitRequested: _confirmExit);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _sitting.dispose();
    super.dispose();
  }

  Future<AppExitResponse> _confirmExit() async {
    if (!_sitting.isBusy) return AppExitResponse.exit;
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('A sitting is in progress'),
        content: const Text(
          'The council is still deliberating. Closing now ends the sitting '
          'where it stands — the rounds already recorded are kept, and it can '
          'be resumed from the barrier it reached.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay open'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close anyway'),
          ),
        ],
      ),
    );
    return leave == true ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  void _go(Region r) {
    setState(() => _region = r);
    // On a narrow window the rail is a sheet, so choosing a region closes it.
    if (!isWide(context) && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    final Session? open = widget.library.open;

    // The tool always moves first. With nothing open, the app is a question,
    // never an empty document waiting to be filled.
    if (open == null) {
      return ArrivalScreen(
        library: widget.library,
        updater: widget.updater,
        onOpenLibrary: () => _go(Region.library),
        onOpenSettings: () => _go(Region.settings),
        showLibrary: _region == Region.library,
        showSettings: _region == Region.settings,
        onLeaveRegion: () => setState(() => _region = Region.interview),
      );
    }

    final Widget content = _content(open);

    if (!isWide(context)) {
      return Scaffold(
        backgroundColor: c.ground,
        appBar: AppBar(
          backgroundColor: c.ground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _region.title,
            style: MiType.heading.copyWith(color: c.ink),
          ),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            color: c.ink,
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              backgroundColor: c.raised,
              builder: (BuildContext context) =>
                  SafeArea(child: _rail(open, sheet: true)),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: MiRule(),
          ),
        ),
        body: content,
      );
    }

    // On a wide window a region opens in the content pane rather than as a
    // pushed route. A push covers the rail too, which turns a 1600px window
    // into a phone page and takes the session list with it.
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(width: MiSpace.railWidth, child: _rail(open)),
            Container(width: 1, color: c.rule),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  Widget _content(Session open) => switch (_region) {
    Region.interview => InterviewScreen(
      library: widget.library,
      session: open,
      onBegun: () => _go(Region.run),
    ),
    Region.run => RunScreen(
      library: widget.library,
      sitting: _sitting,
      session: open,
      onFinished: () => _go(Region.dossier),
    ),
    Region.ledger => LedgerScreen(session: open),
    Region.dossier => DossierScreen(session: open),
    Region.assembly => AssemblyScreen(library: widget.library, session: open),
    Region.pitch => PitchScreen(library: widget.library, session: open),
    Region.library => LibraryScreen(
      library: widget.library,
      onOpened: () => _go(Region.dossier),
    ),
    Region.settings => SettingsScreen(library: widget.library),
  };

  Widget _rail(Session open, {bool sheet = false}) {
    final MiColors c = MiTheme.colorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const MiEyebrow('Before the council'),
              const SizedBox(height: MiSpace.xs),
              Text(
                open.title,
                style: MiType.heading.copyWith(color: c.ink),
              ),
              const SizedBox(height: MiSpace.xs),
              Text(
                '${open.interview.verdict.template.name} · '
                '${open.directions.length} directions',
                style: MiType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        MiRule(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
            children: <Widget>[
              for (final Region r in Region.values)
                _railEntry(r, sheet: sheet),
            ],
          ),
        ),
        MiRule(),
        ListenableBuilder(
          listenable: widget.updater,
          builder: (BuildContext context, _) => Padding(
            padding: const EdgeInsets.all(MiSpace.md),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.updater.hasUpdate
                        ? 'A newer build is ready'
                        : 'Master Idea',
                    style: MiType.caption.copyWith(
                      color: widget.updater.hasUpdate ? c.ink : c.inkMuted,
                    ),
                  ),
                ),
                MiQuietAction(
                  label: widget.updater.hasUpdate ? 'Update' : 'Check',
                  onPressed: () => showUpdateSheet(context, widget.updater),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _railEntry(Region r, {required bool sheet}) {
    final MiColors c = MiTheme.colorsOf(context);
    final bool selected = r == _region;
    // Not a ListTile: it paints its ink on the nearest Material, which inside
    // a ruled page is the page behind it, and Flutter asserts.
    return InkWell(
      onTap: () => _go(r),
      child: Container(
        constraints: const BoxConstraints(minHeight: MiSpace.tapTarget),
        padding: const EdgeInsets.symmetric(
          horizontal: MiSpace.lg,
          vertical: MiSpace.sm,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: MiSpace.md,
              child: selected
                  ? Text('—', style: MiType.body.copyWith(color: c.ink))
                  : null,
            ),
            Expanded(
              child: Text(
                r.title,
                style: MiType.body.copyWith(
                  color: selected ? c.ink : c.inkMuted,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (r == Region.run)
              ListenableBuilder(
                listenable: _sitting,
                builder: (BuildContext context, _) => Text(
                  _sitting.isBusy ? 'in session' : '',
                  style: MiType.caption.copyWith(color: c.inkMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
