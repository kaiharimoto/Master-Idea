import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';
import '../widgets/counts.dart';

/// Sessions stored on disk.
///
/// No accounts, no hosting, nothing shared anywhere. A completed sitting is
/// reopened here and its assembly reconsidered without the council being run
/// again — the dossier and the ledger are read from the files, so a session
/// from last year opens on a machine with no key in it.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({required this.library, required this.onOpened, super.key});

  final Library library;
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: library,
      builder: (BuildContext context, _) {
        final List<Session> sessions = library.sessions;
        if (sessions.isEmpty) {
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
                  subtitle: '${sessions.length} stored on this device, '
                      'reopenable with no council and no network.',
                ),
                const SizedBox(height: MiSpace.lg),
                for (final Session s in sessions) ...<Widget>[
                  MiPanel(
                    child: InkWell(
                      onTap: () {
                        library.select(s.id);
                        onOpened();
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
                            style: MiType.mono.copyWith(color: c.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: MiSpace.sm),
                ],
                const SizedBox(height: MiSpace.lg),
                MiField(
                  label: 'Kept in',
                  child: Text(
                    library.pathOf(sessions.first.id),
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
