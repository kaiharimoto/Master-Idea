import 'package:flutter/material.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
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
class ArrivalScreen extends StatefulWidget {
  const ArrivalScreen({
    required this.library,
    required this.updater,
    required this.onOpenLibrary,
    required this.onOpenSettings,
    required this.showLibrary,
    required this.showSettings,
    required this.onLeaveRegion,
    super.key,
  });

  final Library library;
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
        onBack: widget.onLeaveRegion,
        title: 'Settings',
      );
    }
    if (widget.showLibrary) {
      return _framed(
        c,
        LibraryScreen(library: widget.library, onOpened: widget.onLeaveRegion),
        onBack: widget.onLeaveRegion,
        title: 'Sessions',
      );
    }

    final InterviewDraft? draft = _draft;
    if (draft != null) {
      return Scaffold(
        backgroundColor: c.ground,
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
      backgroundColor: c.ground,
      body: SafeArea(
        child: SingleChildScrollView(
          child: MiLeaf(
            width: MiSpace.readingWidth,
            padding: const EdgeInsets.symmetric(
              horizontal: MiSpace.lg,
              vertical: MiSpace.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MiEyebrow('Master Idea'),
                const SizedBox(height: MiSpace.xl),
                Text(
                  'What is the idea?',
                  style: MiType.question.copyWith(color: c.ink),
                ),
                const SizedBox(height: MiSpace.sm),
                Text(
                  'Say it in your own words, however unfinished. You will be '
                  'interrogated about it once, hard, and then the council goes '
                  'away and argues about it without you.',
                  style: MiType.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: MiSpace.lg),
                MiWriting(
                  controller: _idea,
                  autofocus: true,
                  hint: 'An essay, a story, a song, a program — anything.',
                  onSubmit: _begin,
                ),
                const SizedBox(height: MiSpace.md),
                Row(
                  children: <Widget>[
                    MiAction(label: 'Convene', onPressed: _begin),
                    const SizedBox(width: MiSpace.md),
                    Text(
                      MiSubmit.hintFor(context),
                      style: MiType.caption.copyWith(color: c.inkFaint),
                    ),
                  ],
                ),
                const SizedBox(height: MiSpace.xxl),
                MiRule(),
                const SizedBox(height: MiSpace.md),
                Row(
                  children: <Widget>[
                    MiQuietAction(
                      label: widget.library.isEmpty
                          ? 'No sittings yet'
                          : '${widget.library.sessions.length} stored '
                                'session(s)',
                      onPressed: widget.library.isEmpty
                          ? null
                          : widget.onOpenLibrary,
                    ),
                    const Spacer(),
                    MiQuietAction(
                      label: 'Settings',
                      onPressed: widget.onOpenSettings,
                    ),
                    const SizedBox(width: MiSpace.sm),
                    ListenableBuilder(
                      listenable: widget.updater,
                      builder: (BuildContext context, _) => MiQuietAction(
                        label: widget.updater.hasUpdate
                            ? 'A newer build is ready'
                            : 'Updates',
                        onPressed: () =>
                            showUpdateSheet(context, widget.updater),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _framed(
    MiColors c,
    Widget child, {
    required VoidCallback onBack,
    required String title,
  }) => Scaffold(
    backgroundColor: c.ground,
    appBar: AppBar(
      backgroundColor: c.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Text(title, style: MiType.heading.copyWith(color: c.ink)),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: c.ink,
        onPressed: onBack,
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: MiRule(),
      ),
    ),
    body: child,
  );
}
