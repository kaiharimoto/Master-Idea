import 'dart:io';

import 'package:meta/meta.dart';

import 'turn_plan.dart';

/// What one candidate path turned out to be.
///
/// Every candidate reports an outcome with detail rather than just a name,
/// because 'not installed' is the answer people act on and it must never be
/// guessed. Master Prompt shipped that guess once: on Windows an npm install
/// puts `claude.cmd` on the path, `CreateProcess` refuses to execute it, the
/// probe caught the exception, and the app told a user with a working install
/// that they had none.
@immutable
class ProbeOutcome {
  const ProbeOutcome({
    required this.path,
    required this.usable,
    required this.detail,
    this.version = '',
  });

  final String path;
  final bool usable;
  final String detail;
  final String version;
}

/// A `claude` binary that answered.
@immutable
class ClaudeInstall {
  const ClaudeInstall({
    required this.path,
    required this.throughShell,
    required this.capabilities,
  });

  final String path;
  final bool throughShell;
  final CliCapabilities capabilities;
}

/// Finds the Claude CLI and asks it what it can do.
class ClaudeCli {
  ClaudeCli({this.explicitPath, this.onWindows = false});

  /// A path the user typed in settings.
  ///
  /// **A directive, not a hint.** When one is given it is used alone: a wrong
  /// path is reported as wrong rather than silently bypassed by a working
  /// install somewhere else, because the second behaviour makes a settings
  /// field that appears to do nothing.
  final String? explicitPath;

  /// Taken as a parameter rather than read from `Platform`, so the branch is
  /// reachable from a test on a Linux runner. A branch guarded by an ambient
  /// platform check is a branch with no coverage the moment it is written.
  final bool onWindows;

  final List<ProbeOutcome> attempts = <ProbeOutcome>[];

  /// A `.cmd` or `.bat` has to go through a shell, and only on Windows.
  bool needsShell(String path) {
    if (!onWindows) return false;
    final String lower = path.toLowerCase();
    return lower.endsWith('.cmd') || lower.endsWith('.bat');
  }

  Future<ClaudeInstall?> locate() async {
    attempts.clear();
    for (final String candidate in await _candidates()) {
      final ClaudeInstall? install = await probe(candidate);
      if (install != null) return install;
    }
    return null;
  }

  Future<List<String>> _candidates() async {
    if (explicitPath != null && explicitPath!.trim().isNotEmpty) {
      return <String>[explicitPath!.trim()];
    }
    final List<String> found = <String>[];
    // Ask the operating system before guessing. A fixed list cannot cover
    // winget, an npm global prefix someone moved, or a manual install.
    try {
      final ProcessResult r = onWindows
          ? await Process.run('where', <String>['claude'])
          : await Process.run('which', <String>['-a', 'claude']);
      for (final String line in '${r.stdout}'.split('\n')) {
        if (line.trim().isNotEmpty) found.add(line.trim());
      }
    } on ProcessException catch (e) {
      attempts.add(
        ProbeOutcome(
          path: onWindows ? 'where claude' : 'which -a claude',
          usable: false,
          detail: 'Could not ask the operating system: ${e.message}',
        ),
      );
    }
    found.addAll(<String>[
      if (onWindows) r'%APPDATA%\npm\claude.cmd' else '/usr/local/bin/claude',
      if (!onWindows) '${Platform.environment['HOME']}/.local/bin/claude',
    ]);
    return found;
  }

  /// Ask one candidate whether it is a usable CLI.
  Future<ClaudeInstall?> probe(String path) async {
    final bool shell = needsShell(path);
    try {
      final ProcessResult version = await Process.run(path, <String>[
        '--version',
      ], runInShell: shell);
      if (version.exitCode != 0) {
        attempts.add(
          ProbeOutcome(
            path: path,
            usable: false,
            detail: 'Answered --version with exit code ${version.exitCode}.',
          ),
        );
        return null;
      }
      final ProcessResult help = await Process.run(path, <String>[
        '--help',
      ], runInShell: shell);
      final CliCapabilities capabilities = CliCapabilities.parse(
        '${help.stdout}',
        version: '${version.stdout}'.trim(),
      );
      attempts.add(
        ProbeOutcome(
          path: path,
          usable: true,
          detail: '${capabilities.flags.length} flags read from --help.',
          version: capabilities.version,
        ),
      );
      return ClaudeInstall(
        path: path,
        throughShell: shell,
        capabilities: capabilities,
      );
    } on ProcessException catch (e) {
      attempts.add(
        ProbeOutcome(
          path: path,
          usable: false,
          detail: shell
              ? 'The shell could not run it: ${e.message}'
              : 'Could not be executed: ${e.message}. On Windows a .cmd has to '
                    'go through a shell.',
        ),
      );
      return null;
    }
  }
}
