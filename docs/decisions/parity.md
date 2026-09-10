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
| `analysis_options.yaml` with strict casts, inference and raw types | Copied verbatim, and included by the two Flutter packages as well | Same rules, same failures, in both halves — the app was on the stock Flutter template until this was checked, which made the largest body of code here the least analysed |
| `dart format` as a CI gate | Same, on all four packages | It was gated on the pure two only, and the Flutter two had drifted |
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

## Added when the clients were built

| Matched | Where |
|---|---|
| One Flutter application, two platform folders, both first-class | `app/` — parity is a property of there being one widget tree, not a promise |
| A committed development signing key, so a build installs over the last one | `app/android/dev-keystore.jks`, asserted by fingerprint in CI after every APK |
| One native channel and no more, kept thin because a Linux runner cannot test it | `masteridea/platform`: install an APK, share a file, save a file |
| A `FileProvider` scoped to `cache/` only | `file_paths.xml` — a provider over internal storage would expose every stored session |
| Per-user Inno Setup installer, no UAC, stable `AppId`, silent update with relaunch | `app/windows/installer/master_idea.iss` |
| The build number stamped into the exe's VERSIONINFO by CI | Windows sees every build as 0.1.0.1 otherwise, and cannot tell an upgrade from a reinstall |
| CompanyName and ProductName fixed forever | On Windows they decide where saved sessions live, at runtime |
| An updater that reads a rolling `dev` tag, compares build numbers numerically, and prefers the installer over the zip | `app/lib/src/update/` |
| `AppLifecycleListener` guarding a close mid-sitting | `_HomeScreenState` — the Windows embedder consumes the first WM_CLOSE precisely so the framework can answer |
| No `ListTile` inside a ruled page; a disclosure built with `AnimatedSize` and a conditional child | `mi_design` — both are Master Prompt's scars |

| Deviation | Reason |
|---|---|
| The rolling release publishes from the development branch as well as the default branch | This repository has only the one branch, and a build nobody can download is not a build. See decision 0013. |
| One added colour: `MiColors.verdict`, an oxblood exactly one widget may paint | A council's entire output is judgement, and a dossier that sets its ratings in the same ink as its prose is one you have to read twice to find them in. The first treatment here was a parchment-and-serif court archive; it looked like a different program, which for two halves of one pair is the wrong answer however handsome it is, and it was replaced by Master Prompt's own system. See decision 0015. |
| An eleventh seat, the clerk, which sits before the sitting rather than during it | Master Prompt has no interview to restate. See decision 0018. |
| The phone transport is a hand-carried council rather than a copy-paste interview | The same difference in the other direction: Master Prompt's phone route carries *questions* to a chat, and this one carries *seats*. Both are the same `CouncilTransport` the desktop uses, so neither client is a port of the other. |

## The Android autonomy limit

Recorded here because the brief requires it named rather than discovered: **the
Android client cannot run a sitting unattended, and the desktop transport's
autonomy is never claimed for it.** There is no Claude CLI on a phone, so every
turn goes out by hand and comes back by hand. The sitting screen says so, and
the release notes say so.

Everything else is reachable on both clients: interview, sitting, coverage
ledger, dossier, assembly, pitch and the session library. Assembly was the
exception until this was checked — it asked for the CLI directly, so a phone
could interview, sit and read a dossier and then stop one step short of the
pitch its whole session exists to produce. It now goes through the same
transport as every other turn, which on a phone means one more turn carried by
hand.

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
