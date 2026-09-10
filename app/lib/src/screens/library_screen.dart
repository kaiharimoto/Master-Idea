import 'package:flutter/material.dart';
import 'package:mi_core/mi_core.dart';
import 'package:mi_design/mi_design.dart';

import '../store/library.dart';

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
        return SingleChildScrollView(
          child: MiLeaf(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const MiEyebrow('Sessions'),
                const SizedBox(height: MiSpace.sm),
                Text(
                  sessions.isEmpty
                      ? 'Nothing has been put before the council yet.'
                      : '${sessions.length} stored on this device.',
                  style: MiType.prose.copyWith(color: c.inkMuted),
                ),
                const SizedBox(height: MiSpace.lg),
                for (final Session s in sessions) ...<Widget>[
                  InkWell(
                    onTap: () {
                      library.select(s.id);
                      onOpened();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: MiSpace.md,
                      ),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: c.rule)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            s.title,
                            style: MiType.heading.copyWith(color: c.ink),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${s.interview.verdict.template.name} · '
                            '${s.directions.length} directions · '
                            '${s.ratings.length} verdicts · '
                            '${s.manifest.dryness == null ? 'unfinished' : 'ran dry'}',
                            style: MiType.caption.copyWith(color: c.inkMuted),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.id,
                            style: MiType.mono.copyWith(color: c.inkFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: MiSpace.xl),
                if (sessions.isNotEmpty)
                  MiRecord(
                    label: 'Kept in',
                    value: library.pathOf(sessions.first.id),
                    style: MiType.mono,
                  ),
                const SizedBox(height: MiSpace.sm),
                Text(
                  'Plain files, on this device only. A sitting that took six '
                  'hours of council time should be recoverable with a text '
                  'editor if this app ever fails to start.',
                  style: MiType.caption.copyWith(color: c.inkMuted),
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
