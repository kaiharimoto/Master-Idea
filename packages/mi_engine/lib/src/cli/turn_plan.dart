import 'package:meta/meta.dart';

/// What a `claude` build accepts, read from its own `--help`.
///
/// Never a hardcoded flag list. Master Prompt found `--effort` accepting only
/// `low, medium, high` in a build whose documentation promised more, and
/// `--output-format stream-json` writing nothing at all without `--verbose`.
/// A capability set read from the binary in front of you degrades; a constant
/// in the source is a bug waiting for a release.
@immutable
class CliCapabilities {
  const CliCapabilities({
    required this.version,
    required this.flags,
    required this.values,
  });

  final String version;
  final Set<String> flags;

  /// Flag to the values its help text enumerates, where it enumerates any.
  final Map<String, Set<String>> values;

  bool has(String flag) => flags.contains(flag);

  bool supportsValue(String flag, String value) {
    final Set<String>? known = values[flag];
    // A flag that enumerates nothing — `--model` is the standing example —
    // cannot be checked here, and a bad value fails at run time on every turn.
    // Answering 'yes' is right: refusing would make an unlisted-but-valid
    // value unusable.
    return has(flag) &&
        (known == null || known.isEmpty || known.contains(value));
  }

  /// Read a `claude --help` dump.
  static CliCapabilities parse(String help, {String version = 'unknown'}) {
    final Set<String> flags = <String>{};
    final Map<String, Set<String>> values = <String, Set<String>>{};
    for (final RegExpMatch m in RegExp(
      r'(--[a-z][a-z0-9-]*)',
    ).allMatches(help)) {
      flags.add(m.group(1)!);
    }
    // `(choices: "a", "b")`, which is how the CLI's help enumerates them.
    for (final String line in help.split('\n')) {
      final RegExpMatch? flag = RegExp(r'(--[a-z][a-z0-9-]*)').firstMatch(line);
      if (flag == null) continue;
      final RegExpMatch? choices = RegExp(
        r'choices:\s*([^)]+)',
      ).firstMatch(line);
      if (choices == null) continue;
      values[flag.group(1)!] = <String>{
        for (final RegExpMatch v in RegExp(
          r'"([^"]+)"',
        ).allMatches(choices.group(1)!))
          v.group(1)!,
      };
    }
    return CliCapabilities(version: version, flags: flags, values: values);
  }
}

/// A validated invocation for one council turn.
@immutable
class TurnPlan {
  const TurnPlan({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.throughShell,
    this.notes = const <String>[],
  });

  final String executable;
  final List<String> arguments;
  final String workingDirectory;

  /// Windows cannot execute a `.cmd` directly — `CreateProcess` refuses one,
  /// and an npm install puts `claude.cmd` on the path. Master Prompt reported
  /// that as 'not installed': a confident, actionable, wrong answer.
  final bool throughShell;

  /// Capabilities asked for and not applied, so a degraded turn can say what
  /// it lost instead of silently doing something else.
  final List<String> notes;

  @override
  String toString() => '$executable ${arguments.join(' ')}';
}

class TurnPlanError implements Exception {
  TurnPlanError(this.message);
  final String message;
  @override
  String toString() => 'TurnPlanError: $message';
}

/// Composes the arguments for one turn. Pure, so a test can inspect an
/// invocation without spawning anything.
///
/// **Every council turn is a fresh one-shot call.** There is no `--resume`
/// here and no session id, which is a real difference from Master Prompt and
/// not an omission: seats must not share a conversation, or an assessor
/// inherits the prospector's case for the direction it is judging and the
/// independent-rating invariant is broken by the transport with no code
/// passing anything.
abstract final class TurnPlanBuilder {
  static TurnPlan build({
    required String executable,
    required CliCapabilities capabilities,
    required String workingDirectory,
    bool throughShell = false,
    String? model,
    List<String> effortPreference = const <String>['medium', 'low'],
  }) {
    final List<String> args = <String>[];
    final List<String> notes = <String>[];

    // Without --print the CLI opens an interactive session, which cannot be
    // driven and simply hangs.
    if (!capabilities.has('--print')) {
      throw TurnPlanError(
        'This claude build (${capabilities.version}) has no --print flag, so '
        'it cannot be run non-interactively.',
      );
    }
    args.add('--print');

    if (capabilities.supportsValue('--output-format', 'stream-json') &&
        capabilities.has('--verbose')) {
      // Verified against the binary by the other half of this pair:
      // stream-json writes nothing at all without --verbose, which is
      // indistinguishable from a hang.
      args
        ..addAll(<String>['--output-format', 'stream-json'])
        ..add('--verbose');
    } else if (capabilities.supportsValue('--output-format', 'text')) {
      args.addAll(<String>['--output-format', 'text']);
      notes.add(
        'This build cannot stream events, so a turn is invisible until it '
        'finishes and token usage is not reported.',
      );
    }

    // Never the client's run setting, and never bypassPermissions. A seat
    // arguing about what an idea could be needs no tools at all, and a council
    // that can touch the filesystem is a council that can be talked into it.
    if (capabilities.supportsValue('--permission-mode', 'default')) {
      args.addAll(<String>['--permission-mode', 'default']);
    }

    if (model != null &&
        model.trim().isNotEmpty &&
        capabilities.has('--model')) {
      args.addAll(<String>['--model', model.trim()]);
    }

    if (capabilities.has('--effort')) {
      final String effort = effortPreference.firstWhere(
        (String e) => capabilities.supportsValue('--effort', e),
        orElse: () => '',
      );
      if (effort.isNotEmpty) {
        args.addAll(<String>['--effort', effort]);
        if (effort != effortPreference.first) {
          notes.add(
            'Effort reduced to "$effort": this build does not accept '
            '"${effortPreference.first}".',
          );
        }
      }
    }

    return TurnPlan(
      executable: executable,
      arguments: args,
      workingDirectory: workingDirectory,
      throughShell: throughShell,
      notes: notes,
    );
  }
}
