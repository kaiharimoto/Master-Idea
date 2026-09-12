/// Domain core for Master Idea.
///
/// Pure Dart: no Flutter, no `dart:io`. The council, the session record, the
/// three hard invariants and the renderers all live here, and every one of
/// them is exercisable without a process, a network or an interface — which
/// is the property that lets a six-hour unattended run be trusted, and the
/// one Master Prompt learned to protect by keeping its own core free of both.
library;

export 'src/assembly/integration.dart';
export 'src/council/angles.dart';
export 'src/council/dimensions.dart';
export 'src/council/profiles.dart';
export 'src/council/roles.dart';
export 'src/council/templates.dart';
export 'src/interview/interview_counsel.dart';
export 'src/interview/interview_gate.dart';
export 'src/interview/modules.dart';
export 'src/invariants/invariant_suite.dart';
export 'src/pitch/pitch_prompt.dart';
export 'src/render/document.dart';
export 'src/render/dossier.dart';
export 'src/render/ledger_view.dart';
export 'src/render/round_account.dart';
export 'src/run/council_prompts.dart';
export 'src/run/council_run.dart';
export 'src/run/council_turn.dart';
export 'src/run/dedup.dart';
export 'src/run/run_clock.dart';
export 'src/session/direction.dart';
export 'src/session/ledger.dart';
export 'src/session/manifest.dart';
export 'src/session/rating.dart';
export 'src/session/round.dart';
export 'src/session/session.dart';
export 'src/session/session_title.dart';
