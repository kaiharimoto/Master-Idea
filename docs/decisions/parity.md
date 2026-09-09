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

## Added when the engine was built

| Matched | Where |
|---|---|
| Capabilities read from the binary's own `--help`, never hardcoded | `CliCapabilities.parse` — the other half found `--effort` accepting only `low, medium, high` against its documentation |
| `--print` mandatory; `stream-json` requires `--verbose` | `TurnPlanBuilder` — without `--verbose` the CLI writes nothing at all, which presents as a hang |
| A `.cmd` or `.bat` goes through a shell, on Windows only, and the platform is a parameter | `ClaudeCli.needsShell(onWindows:)` — a branch behind an ambient `Platform.isWindows` has no coverage on a Linux runner |
| An explicit path in settings is a directive, used alone | `ClaudeCli._candidates` |
| The child's stdin is closed explicitly after `Process.start` | `CliCouncil.ask` — otherwise the CLI waits for piped input on every turn |
| A usage limit is read from **stderr only** | `CliCouncil._limitUntil` — limit text can never reach the stdout JSON stream |
| A fake binary that refuses what the real one refuses | `tool/fake_council.dart` |
| Atomic writes, temp file then rename | `SessionStore._json` |
| Ids monotonic in-process and floored by what is on disk, with the clock injected | `SessionStore.mintId` — the other half lost a mission to two ids minted inside one Windows clock tick |

| Deviation | Reason |
|---|---|
| No session id, no `--resume`, no `--continue`: every council turn is a fresh one-shot call | Master Prompt's interview is deliberately *one continuing chat*, because a conversation is the point. Here the opposite property is required: seats sharing a conversation share context, and an assessor that inherits a prospector's case is rating the advocacy. Independence beats continuity, so each turn stands alone. |
| The prompt goes down stdin rather than on the command line | Master Prompt guards a 7,800-character budget on a `.cmd` install and demotes the pipe route there. A propose turn runs to several thousand characters and is sent on every seat, so stdin is the primary route here rather than the fallback. |
