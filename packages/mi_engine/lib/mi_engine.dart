/// Headless session driving for Master Idea.
///
/// `dart:io` only — no Flutter — so the store, the Claude CLI transport and
/// the whole command-line path can be exercised on a Linux runner against a
/// fake binary, without an API key and without a six-hour wait. Master Prompt
/// draws the line in the same place and for the same reason.
library;

export 'src/cli/claude_cli.dart';
export 'src/cli/turn_plan.dart';
export 'src/store/session_store.dart';
export 'src/transport/cli_council.dart';
