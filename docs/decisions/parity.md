# Parity with Master Prompt

Where this build matches github.com/kaiharimoto/Master-Prompt's architecture,
and every point where it deviates with the reason. Updated as the build
proceeds; a deviation added later is added here at the moment it is made.

## Matched

| Master Prompt | Master Idea | Why it matters |
|---|---|---|
| `mp_core`, pure Dart, no Flutter and no `dart:io` | `mi_core`, same rule | The logic that has to be right during a long unattended run is analysable and testable in seconds without a 2.5 GB SDK |
| `mp_runner`, `dart:io` only | `mi_engine`, same rule | The process and filesystem work is provable on a Linux runner before any Windows box sees it |
| Path dependencies, **no pub workspace** | Same | A workspace including the Flutter packages makes `dart pub get` need the Flutter SDK, which breaks CI for the pure packages |
| `analysis_options.yaml` with strict casts, inference and raw types | Copied verbatim | Same rules, same failures, in both halves |
| `dart format` as a CI gate on the pure packages | Same | |
| Line-oriented wire format for anything a model writes mid-run (`mpstate`) | The whole council grammar | A truncated line grammar loses one field; a truncated JSON object loses everything |
| Injected clock, so waits are testable (`RunSupervisor`) | `RunClock` | A limit pause measured in hours cannot be tested against a real clock |
| One code path to the model, with a fake that refuses what the real one refuses | `CouncilTransport` with `ScriptedCouncil` | A double that accepts everything proves only that the code runs |
| A value the model proposed is `proposed`, never `confirmed` | Carried across the seam: the `mi-pitch` import arrives in Master Prompt proposed | A hallucinated requirement must not satisfy a readiness gate in either tool |

## Deviations

| Deviation | Reason |
|---|---|
| The brief's `test/invariants/` is `packages/mi_core/lib/src/invariants/` plus `packages/mi_core/test/invariants_test.dart` | The suite is not only a test — the app runs it on demand against a stored session — and logic the app calls belongs in the pure package. A root test directory would also need its own pubspec and CI job purely for its name. See decision 0006. |
| Package names differ (`mi_` rather than `mp_`) | Two packages called `mp_core` on one machine are ambiguous in every import. |
| `mi_engine` drives many concurrent seats where `mp_runner` supervises one long conversation | A difference in what the package does, not in where the architectural line is drawn. |

## Not yet claimed

Nothing about the Android and Windows clients is recorded here yet, because
neither has been started. The transport difference and the Android autonomy
limit — the Android client cannot run unattended, and the desktop transport's
autonomy may not be claimed for it — are recorded here the moment the first
client work begins, not retroactively.
