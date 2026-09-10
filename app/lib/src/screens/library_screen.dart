import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../store/sitting.dart';
import '../widgets/counts.dart';

/// Sessions stored on disk.
///
/// No accounts, no hosting, nothing shared anywhere. A completed sitting is
/// reopened here and its assembly reconsidered without the council being run
/// again — the dossier and the ledger are read from the files, so a session
/// from last year opens on a machine with no key in it.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.library,
    required this.sitting,
    required this.onOpened,
    super.key,
  });

  final Library library;
  final Sitting sitting;
  final VoidCallback onOpened;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final TextEditingController _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _delete(Session s) async {
    if (widget.sitting.isBusy && widget.sitting.sessionId == s.id) {
      miNotice(context, 'The council is sitting on this one. Stop it first.');
      return;
    }
    final bool go = await showMiConfirm(
      context,
      title: 'Delete “${s.title}”?',
      body:
          'This removes its files from this device. Nothing is hosted '
          'anywhere, so nothing else has a copy — the interview, the rounds, '
          'the verdicts and the pitch all go.',
      action: 'Delete it',
    );
    if (!go) return;
    try {
      await widget.library.delete(s.id);
      if (mounted) miNotice(context, 'Deleted');
    } on Object catch (e) {
      if (mounted) miNotice(context, 'It could not be deleted. $e');
    }
  }

  /// Open the folder a session lives in, on a platform that has folders.
  Future<void> _show(Session s) async {
    final String path = widget.library.pathOf(s.id);
    if (path.isEmpty) return;
    try {
      if (Platform.isWindows) {
        await Process.start('explorer', <String>[path]);
      } else if (Platform.isMacOS) {
        await Process.start('open', <String>[path]);
      } else {
        await Process.start('xdg-open', <String>[path]);
      }
    } on Object {
      if (mounted) miNotice(context, path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.library,
        widget.sitting,
      ]),
      builder: (BuildContext context, _) {
        final String needle = _filter.text.trim().toLowerCase();
        final List<Session> all = widget.library.sessions;
        final List<Session> sessions = needle.isEmpty
            ? all
            : all
                  .where(
                    (Session s) =>
                        s.title.toLowerCase().contains(needle) ||
                        s.id.toLowerCase().contains(needle),
                  )
                  .toList();

        if (all.isEmpty) {
          return const MiEmpty(
            title: 'Nothing has been put before the council yet',
            detail:
                'Every session is kept on this device as plain files — no '
                'account, nothing hosted. A sitting that took six hours should '
                'be recoverable with a text editor if this app ever fails to '
                'start.',
          );
        }

        return SingleChildScrollView(
          child: MiLeaf(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MiSectionHeader(
                  title: 'Sessions',
                  subtitle:
                      '${all.length} stored on this device, reopenable with '
                      'no council and no network.',
                ),
                const SizedBox(height: MiSpace.md),
                if (all.length > 4) ...<Widget>[
                  MiWriting(
                    controller: _filter,
                    minLines: 1,
                    maxLines: 1,
                    hint: 'Find one by name.',
                    onChanged: (String _) => setState(() {}),
                  ),
                  const SizedBox(height: MiSpace.md),
                ],
                if (sessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: MiSpace.lg),
                    child: Text(
                      'Nothing here matches that.',
                      style: MiType.prose.copyWith(color: c.inkMuted),
                    ),
                  ),
                for (final Session s in sessions) ...<Widget>[
                  MiPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Semantics(
                          button: true,
                          label: s.title,
                          child: InkWell(
                            onTap: () {
                              widget.library.select(s.id);
                              widget.onOpened();
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  s.title,
                                  style: MiType.heading.copyWith(color: c.ink),
                                ),
                                const SizedBox(height: MiSpace.sm),
                                Wrap(
                                  spacing: MiSpace.sm,
                                  runSpacing: MiSpace.xs,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    MiTag(s.interview.verdict.template.name),
                                    MiTag(
                                      s.manifest.dryness == null
                                          ? 'unfinished'
                                          : 'ran dry',
                                      tone: s.manifest.dryness == null
                                          ? c.inkMuted
                                          : c.success,
                                    ),
                                    if (widget.sitting.isBusy &&
                                        widget.sitting.sessionId == s.id)
                                      MiTag('in session', tone: c.ink),
                                    Text(
                                      '${countOf(s.directions.length, 'direction')} · '
                                      '${countOf(s.ratings.length, 'verdict')}',
                                      style: MiType.caption.copyWith(
                                        color: c.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: MiSpace.sm),
                                Text(
                                  s.id,
                                  style: MiType.mono.copyWith(
                                    color: c.inkFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: MiSpace.sm),
                        Wrap(
                          spacing: MiSpace.sm,
                          runSpacing: MiSpace.xs,
                          children: <Widget>[
                            MiButton(
                              label: 'Delete',
                              kind: MiButtonKind.quiet,
                              onPressed: () => _delete(s),
                            ),
                            if (!Platform.isAndroid && !Platform.isIOS)
                              MiButton(
                                label: 'Show the files',
                                kind: MiButtonKind.quiet,
                                onPressed: () => _show(s),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MiSpace.sm),
                ],
                const SizedBox(height: MiSpace.lg),
                MiField(
                  label: 'Kept in',
                  child: Text(
                    widget.library.root,
                    style: MiType.mono.copyWith(color: c.inkMuted),
                  ),
                ),
                const SizedBox(height: MiSpace.xxl),
              ],
            ),
          ),
        );
      },
    );
  }
}
