import 'dart:io';

import 'package:mi_engine/mi_engine.dart';
import 'package:path_provider/path_provider.dart';

import '../store/settings.dart';

/// How this app opens a conversation with the Claude CLI. One place, on
/// purpose.
///
/// Three things are decided here and would be free to drift if a second copy
/// existed, and every one of them was learned the hard way in the other half
/// of this pair:
///
/// **A turn runs in a directory of the council's own**, never the client's
/// project, so a `CLAUDE.md` in whatever the idea is *about* does not join the
/// deliberation uninvited and start an argument about a codebase.
///
/// **The permission mode is pinned to `default`.** A seat arguing about what an
/// idea could be needs no tools at all, and a council that can touch the
/// filesystem is a council that can be talked into it.
///
/// **An explicit path is a directive.** When the client has typed one it is
/// used alone, so a wrong path is reported as wrong rather than silently
/// bypassed by a working install somewhere else.
class CouncilSession {
  const CouncilSession({required this.council, required this.install});

  final CliCouncil council;
  final ClaudeInstall install;
}

/// What was tried, when nothing answered.
class NoCouncil implements Exception {
  NoCouncil(this.attempts);

  final List<ProbeOutcome> attempts;

  /// Written for the client rather than for a log: "not installed" is the
  /// answer people act on, so it never appears without what was tried.
  @override
  String toString() => attempts.isEmpty
      ? 'No Claude CLI was found on this machine.'
      : 'No Claude CLI answered. Tried:\n'
            '${attempts.map((ProbeOutcome o) => '  ${o.path} — ${o.detail}').join('\n')}';
}

Future<CouncilSession> openCouncil({
  required Settings settings,
  required String sessionId,
}) async {
  final ClaudeCli cli = ClaudeCli(
    explicitPath: settings.claudePath,
    onWindows: Platform.isWindows,
  );
  final ClaudeInstall? install = await cli.locate();
  if (install == null) throw NoCouncil(cli.attempts);

  final Directory support = await getApplicationSupportDirectory();
  final Directory scratch = Directory(
    '${support.path}${Platform.pathSeparator}council'
    '${Platform.pathSeparator}$sessionId',
  );
  if (!scratch.existsSync()) scratch.createSync(recursive: true);

  return CouncilSession(
    install: install,
    council: CliCouncil(
      install: install,
      workingDirectory: scratch.path,
      model: settings.model.trim().isEmpty ? null : settings.model.trim(),
    ),
  );
}

/// Whether this platform can drive a council on its own.
///
/// A **platform** question, not a layout one. The Android client cannot run a
/// sitting unattended and must never be presented as if it could: there is no
/// CLI on a phone, so every turn there goes out by hand and comes back by
/// hand.
bool get canDriveCouncil =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
