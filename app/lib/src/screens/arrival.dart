import 'package:flutter/material.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/sitting.dart';
import '../update/updater.dart';
import 'interview_proceeding.dart';
import 'library_screen.dart';
import 'settings_screen.dart';
import 'update_sheet.dart';

/// The app before any session exists.
///
/// **The tool moves first.** There is no blank canvas here and never is: the
/// first thing on screen is the council's own question, and answering it is
/// what starts a session. An empty document waiting to be filled would put the
/// work back on the person who came here precisely because they have an
/// unfinished idea and no idea what to do with it.
///
/// Built from [MiFocal], like every other question in this pair of programs:
/// one subject, one supporting line, one action, and everything else folded
/// away beneath.
class ArrivalScreen extends StatefulWidget {
  const ArrivalScreen({
    required this.library,
    required this.sitting,
    required this.updater,
    required this.onOpenLibrary,
    required this.onOpenSettings,
    required this.showLibrary,
    required this.showSettings,
    required this.onLeaveRegion,
    super.key,
  });

  final Library library;
  final Sitting sitting;
  final Updater updater;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenSettings;
  final bool showLibrary;
  final bool showSettings;
  final VoidCallback onLeaveRegion;

  @override
  State<ArrivalScreen> createState() => _ArrivalScreenState();
}

class _ArrivalScreenState extends State<ArrivalScreen> {
  final TextEditingController _idea = TextEditingController();
  InterviewDraft? _draft;

  @override
  void dispose() {
    _idea.dispose();
    _draft?.dispose();
    super.dispose();
  }

  void _begin() {
    final String said = _idea.text.trim();
    if (said.isEmpty) return;
    setState(() {
      _draft = InterviewDraft(rawIdea: said);
      _idea.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);

    if (widget.showSettings) {
      return _framed(
        c,
        SettingsScreen(library: widget.library),
        title: 'Settings',
      );
    }
    if (widget.showLibrary) {
      return _framed(
        c,
        LibraryScreen(
          library: widget.library,
          sitting: widget.sitting,
          onOpened: widget.onLeaveRegion,
        ),
        title: 'Sessions',
      );
    }

    final InterviewDraft? draft = _draft;
    if (draft != null) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          child: InterviewProceeding(
            draft: draft,
            library: widget.library,
            onAbandoned: () => setState(() {
              _draft?.dispose();
              _draft = null;
            }),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.canvas,
      body: SafeArea(
        child: MiFocal(
          eyebrow: 'Master Idea',
          question: 'What is the idea?',
          supporting:
              'Say it in your own words, however unfinished. You will be '
              'interrogated about it once, hard, and then the council goes '
              'away and argues about it without you.',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              MiWriting(
                controller: _idea,
                autofocus: true,
                hint: 'An essay, a story, a song, a program — anything.',
                onSubmit: _begin,
              ),
              const SizedBox(height: MiSpace.sm),
              Text(
                '${MiSubmit.hintFor(context)}, or the button below.',
                style: MiType.caption.copyWith(color: c.inkFaint),
              ),
            ],
          ),
          primary: MiButton(
            label: 'Convene',
            kind: MiButtonKind.primary,
            expand: true,
            onPressed: _begin,
          ),
          disclosures: <Widget>[
            MiDisclosure(
              label: 'Sessions already before the council',
              trailingNote: widget.library.isEmpty
                  ? 'none yet'
                  : '${widget.library.sessions.length}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (widget.library.isEmpty)
                    Text(
                      'Nothing has been put before the council on this device '
                      'yet. Every session is kept here as plain files, with no '
                      'account and nothing hosted anywhere.',
                      style: MiType.prose.copyWith(color: c.inkMuted),
                    )
                  else
                    MiButton(
                      label: 'Open the session library',
                      onPressed: widget.onOpenLibrary,
                    ),
                ],
              ),
            ),
            MiDisclosure(
              label: 'Settings and updates',
              trailingNote: widget.updater.hasUpdate ? 'update ready' : null,
              child: Wrap(
                spacing: MiSpace.sm,
                runSpacing: MiSpace.sm,
                children: <Widget>[
                  MiButton(label: 'Settings', onPressed: widget.onOpenSettings),
                  ListenableBuilder(
                    listenable: widget.updater,
                    builder: (BuildContext context, _) => MiButton(
                      label: widget.updater.hasUpdate
                          ? 'Install the newer build'
                          : 'Check for updates',
                      kind: widget.updater.hasUpdate
                          ? MiButtonKind.primary
                          : MiButtonKind.secondary,
                      onPressed: () => showUpdateSheet(context, widget.updater),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _framed(MiColors c, Widget child, {required String title}) => Scaffold(
    backgroundColor: c.canvas,
    appBar: AppBar(
      backgroundColor: c.canvas,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(title, style: MiType.heading.copyWith(color: c.ink)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: c.ink,
        onPressed: widget.onLeaveRegion,
      ),
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: MiRule(),
      ),
    ),
    body: child,
  );
}
