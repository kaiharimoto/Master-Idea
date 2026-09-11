import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../app.dart';
import '../widgets/counts.dart';
import '../store/library.dart';
import '../store/naming.dart';
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

  /// True while the rail is open as a sheet on a narrow window. Tracked rather
  /// than inferred from `canPop`, which is true of any route — including a
  /// dialog the client is reading, which choosing a region used to dismiss.
  bool _railIsOpen = false;

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
    final bool leave = await showMiConfirm(
      context,
      title: 'A sitting is in progress',
      body:
          'The council is still deliberating. Closing now ends the sitting '
          'where it stands — every round that has closed is kept, and it '
          'resumes from the barrier it reached.',
      action: 'Close anyway',
      cancel: 'Stay open',
    );
    // Stopped rather than abandoned. The council runs in child processes of
    // this one; leaving them behind would keep spending model calls on a
    // session nobody is watching, with nothing left to write them into.
    if (leave) _sitting.stop();
    return leave ? AppExitResponse.exit : AppExitResponse.cancel;
  }

  void _go(Region r) {
    setState(() => _region = r);
    // On a narrow window the rail is a sheet, so choosing a region closes it.
    if (_railIsOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// One step back, for the system back gesture.
  ///
  /// Regions are state rather than routes, so without this the back button
  /// leaves the application from anywhere — mid-interview, mid-sitting, with
  /// no confirmation of any kind.
  Future<void> _back() async {
    if (_railIsOpen) return;
    if (_region != Region.interview) {
      setState(() => _region = Region.interview);
      return;
    }
    final bool close = await showMiConfirm(
      context,
      title: 'Close this session?',
      body: _sitting.isBusy
          ? 'The sitting carries on; you can reopen the session from the '
                'library at any time.'
          : 'Nothing is lost. Everything is on this device as plain files, '
                'and the session reopens from the library.',
      action: 'Close it',
      cancel: 'Stay here',
    );
    if (close) widget.library.close();
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
        sitting: _sitting,
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
      return PopScope(
        // Regions are state rather than routes, so the system back gesture
        // has nothing of its own to pop and leaves the application from
        // anywhere. Handled here instead: back steps to the interview, then
        // asks before closing the session.
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: c.canvas,
          appBar: AppBar(
            backgroundColor: c.canvas,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              _region.title,
              style: MiType.heading.copyWith(color: c.ink),
            ),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              color: c.ink,
              tooltip: 'Regions',
              onPressed: () async {
                _railIsOpen = true;
                await showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: c.surfaceRaised,
                  builder: (BuildContext context) =>
                      SafeArea(child: _rail(open, sheet: true)),
                );
                _railIsOpen = false;
              },
            ),
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: MiRule(),
            ),
          ),
          body: content,
        ),
      );
    }

    // On a wide window a region opens in the content pane rather than as a
    // pushed route. A push covers the rail too, which turns a 1600px window
    // into a phone page and takes the session list with it.
    //
    // Escape steps back the same way the system gesture does on a phone, which
    // is what a desktop user will try. `MiEscape` has existed in the design
    // system since it was written and had no caller.
    return MiEscape(
      onEscape: _back,
      child: Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(width: MiSpace.railWidth, child: _rail(open)),
              Container(width: 1, color: c.line),
              Expanded(child: content),
            ],
          ),
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
      onOpenSettings: () => _go(Region.settings),
    ),
    Region.ledger => LedgerScreen(
      session: open,
      onOpenSitting: () => _go(Region.run),
    ),
    Region.dossier => DossierScreen(
      session: open,
      onOpenSitting: () => _go(Region.run),
    ),
    Region.assembly => AssemblyScreen(
      library: widget.library,
      sitting: _sitting,
      session: open,
      onOpenSitting: () => _go(Region.run),
    ),
    Region.pitch => PitchScreen(
      library: widget.library,
      session: open,
      onOpenAssembly: () => _go(Region.assembly),
    ),
    Region.library => LibraryScreen(
      library: widget.library,
      sitting: _sitting,
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
            MiSpace.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const MiEyebrow('Before the council'),
              const SizedBox(height: MiSpace.sm),
              Text(open.title, style: MiType.heading.copyWith(color: c.ink)),
              const SizedBox(height: MiSpace.sm),
              // A rail is 300px wide and a tier name plus a count does not
              // always fit in it. Wrapping rather than overflowing, because a
              // rail that reports a layout error is a rail nobody trusts.
              Wrap(
                spacing: MiSpace.sm,
                runSpacing: MiSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  MiTag(tierName(open.interview.verdict)),
                  Text(
                    countOf(open.directions.length, 'direction'),
                    style: MiType.caption.copyWith(color: c.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
        const MiRule(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: MiSpace.sm),
            children: <Widget>[
              for (final Region r in Region.values) _railEntry(r, sheet: sheet),
            ],
          ),
        ),
        const MiRule(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            MiSpace.lg,
            MiSpace.md,
            MiSpace.lg,
            0,
          ),
          child: MiButton(
            label: 'Put a new idea before the council',
            expand: true,
            onPressed: _newIdea,
          ),
        ),
        const SizedBox(height: MiSpace.sm),
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
                MiButton(
                  label: widget.updater.hasUpdate ? 'Update' : 'Check',
                  onPressed: () => showUpdateSheet(context, widget.updater),
                  kind: MiButtonKind.quiet,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Back to the opening question.
  ///
  /// Without this there is no way to convene a second idea short of killing
  /// the application: the arrival screen is shown only when no session is
  /// open, and nothing ever closed one.
  Future<void> _newIdea() async {
    if (_railIsOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      _railIsOpen = false;
    }
    if (_sitting.isBusy) {
      final bool go = await showMiConfirm(
        context,
        title: 'A sitting is in progress',
        body:
            'It carries on while you work on something else — it never waits '
            'on you. The session stays in the library, and its rounds keep '
            'arriving.',
        action: 'Start another idea',
        cancel: 'Stay here',
      );
      if (!go) return;
    }
    widget.library.close();
    setState(() => _region = Region.interview);
  }

  Widget _railEntry(Region r, {required bool sheet}) {
    final MiColors c = MiTheme.colorsOf(context);
    final bool selected = r == _region;
    // Not a ListTile: it paints its ink on the nearest Material, which inside
    // a ruled page is the page behind it, and Flutter asserts.
    return Semantics(
      button: true,
      selected: selected,
      label: r.title,
      child: InkWell(
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
                    // A turn waiting to be carried is the one thing on this
                    // rail the client has to act on, and on a phone the rail
                    // is a sheet they may have closed over it.
                    _sitting.needsHand
                        ? 'carry a turn'
                        : _sitting.isHeld
                        ? 'paused'
                        : _sitting.isBusy
                        ? 'in session'
                        : '',
                    style: MiType.caption.copyWith(
                      color: _sitting.needsHand ? c.ink : c.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
