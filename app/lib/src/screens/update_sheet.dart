import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mi_design/mi_design.dart';

import '../store/build_info.dart';
import '../update/release.dart';
import '../update/updater.dart';

/// The one place updating is offered.
///
/// It says which build is running and which is published, in the same shape,
/// so the two can be compared by eye. Every failure carries its reason: an
/// updater that says only "update failed" is what makes updating feel broken
/// rather than merely unlucky.
Future<void> showUpdateSheet(BuildContext context, Updater updater) {
  final MiColors c = MiTheme.colorsOf(context);
  // Checking on open rather than on a button: the sheet exists because someone
  // wants to know, and making them ask twice is a step for nothing. The error
  // from last time goes first — it was never cleared, so a failure from an
  // hour ago sat above a check that had since succeeded.
  if (!updater.busy) {
    updater.clearError();
    unawaited(updater.runCheck());
  }
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surfaceRaised,
    isScrollControlled: true,
    builder: (BuildContext context) =>
        SafeArea(child: _UpdateSheet(updater: updater)),
  );
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({required this.updater});

  final Updater updater;

  @override
  Widget build(BuildContext context) {
    final MiColors c = MiTheme.colorsOf(context);
    return ListenableBuilder(
      listenable: updater,
      builder: (BuildContext context, _) {
        final UpdateCheck? check = updater.check;
        final ReleaseAsset? asset = check?.asset;

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.lg,
            MiSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const MiSectionHeader(title: 'Updates'),
              const SizedBox(height: MiSpace.md),
              MiPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    MiField(
                      label: 'Running',
                      child: Text(
                        BuildInfo.label,
                        style: MiType.numeric.copyWith(color: c.ink),
                      ),
                    ),
                    if (asset != null) ...<Widget>[
                      const SizedBox(height: MiSpace.md),
                      MiField(
                        label: 'Published',
                        child: Text(
                          '${asset.label(BuildInfo.version)}  ${asset.size}'
                              .trim(),
                          style: MiType.numeric.copyWith(color: c.ink),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: MiSpace.md),
              if (updater.phase == UpdatePhase.downloading &&
                  updater.progress >= 0) ...<Widget>[
                MiMeter(value: updater.progress),
                const SizedBox(height: MiSpace.sm),
              ],
              Text(switch (updater.phase) {
                UpdatePhase.checking => 'Reading the release page…',
                UpdatePhase.downloading =>
                  updater.progress < 0
                      ? 'Downloading…'
                      : 'Downloading — '
                            '${(updater.progress * 100).round()} per cent',
                UpdatePhase.downloaded => 'Downloaded and ready to install.',
                UpdatePhase.installing => 'Handed to the installer.',
                _ => check?.detail ?? 'Nothing checked yet.',
              }, style: MiType.prose.copyWith(color: c.ink)),
              if (updater.error != null) ...<Widget>[
                const SizedBox(height: MiSpace.md),
                MiPanel(
                  accent: c.danger,
                  child: Text(
                    updater.error!,
                    style: MiType.prose.copyWith(color: c.ink),
                  ),
                ),
              ],
              if (updater.handoff != null) ...<Widget>[
                const SizedBox(height: MiSpace.md),
                MiPanel(
                  accent: c.ink,
                  child: Text(
                    updater.handoff!,
                    style: MiType.prose.copyWith(color: c.ink),
                  ),
                ),
              ],
              const SizedBox(height: MiSpace.lg),
              Wrap(
                spacing: MiSpace.sm,
                runSpacing: MiSpace.sm,
                children: <Widget>[
                  if (updater.hasUpdate && updater.file == null)
                    MiButton(
                      label: 'Download',
                      busy: updater.phase == UpdatePhase.downloading,
                      onPressed: updater.busy ? null : updater.download,
                      kind: MiButtonKind.primary,
                    ),
                  if (updater.file != null)
                    MiButton(
                      label: 'Install',
                      busy: updater.phase == UpdatePhase.installing,
                      onPressed: updater.busy || updater.quitting
                          ? null
                          : updater.install,
                      kind: MiButtonKind.primary,
                    ),
                  MiButton(
                    label: 'Check again',
                    busy: updater.phase == UpdatePhase.checking,
                    onPressed: updater.busy ? null : updater.runCheck,
                    kind: MiButtonKind.secondary,
                  ),
                ],
              ),
              const SizedBox(height: MiSpace.md),
              Text(
                'Builds come from the rolling dev release. On Windows the '
                'installer closes this app, replaces it and opens it again; on '
                'Android the system installer asks you to confirm, and the new '
                'build installs over this one keeping every stored session.',
                style: MiType.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
