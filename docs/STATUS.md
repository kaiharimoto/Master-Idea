# Status

Where the build actually is. Kept current as part of every change, because it
is the only thing that tells the next session where we were.

**Last updated:** the session that built both clients and the release
pipeline — a signed APK and a Windows installer, published to a rolling `dev`
release that the app updates itself from.

## Done

`packages/mi_core` — the engine, and `packages/mi_engine` — the store, the
Claude CLI transport and the headless entry point. Both analysed, formatted and
green: 86 tests and 27.

- **Families.** Ten council roles, twelve exploration angles, six rating
  dimensions with six closed ordinal vocabularies, four harness templates,
  seven domain profiles, fifteen interview modules. Every floor in the brief is
  met or exceeded, and `families_test.dart` asserts the distinctness that makes
  the counts mean something — no two roles sharing a lens, no two dimensions
  catching the same failure, no two profiles differing only in wording.
- **The interview gate.** Composed from the module bank per medium, ordered by
  the bank rather than by the medium, and refusing to close over an unanswered
  module, an empty brief, an unserved part or an empty list of declared
  unknowns.
- **The run.** Rounds as barriers; angles concurrent and blind; challenge and
  rating pipelined per direction as it arrives; deduplication and acceptance in
  one synchronous stretch so two converging angles cannot both accept the same
  proposal; provider limits waited out as pauses and excluded from council
  time; every model call recorded in a machine-written manifest.
- **The three invariants**, enforced during the run and checkable afterwards by
  `InvariantSuite` against a stored session alone. Twelve negative tests break
  each invariant in turn and prove the suite fails.
- **The renderers** — dossier, coverage ledger, pitch — pure over the stored
  session, proven with a transport that throws if anything touches it.

And the headless spine, driven as a person would drive it:

```bash
mi new    sessions/ interview.json     # the gate refuses a run without a licence
mi run    sessions/ <id>               # deliberate to dryness through the CLI
mi check  sessions/ [<id>]             # the invariant suite, exit code and all
mi render sessions/ <id> dossier|ledger|pitch
mi select sessions/ <id> d-0001 ...    # compute the integration, write the pitch
```

Every step of that is tested as a real subprocess, because a command whose exit
code is wrong is a check that silently always passes. The council in those
tests is a compiled fake binary that refuses what the real one refuses — a
missing `--print`, an unknown flag, stream-json without `--verbose`, a stdin
that never reaches EOF.

## The seam to Master Prompt

Done and tested from both sides. A finished session exports `pitch.md`; pasting
it into Master Prompt's mission picker opens a mission there with the values
proposed and the whole document kept as a received exchange. `IdeaPitch` lives
in that program's `mp_core`, its fixtures are pitches this one actually
produced, and decision 0011 records why the seam is a paste rather than a file
or a protocol.

## The clients, and builds you can install

Both clients exist and are built by CI on every push, published to the rolling
`dev` release: a signed APK and a per-user Windows installer, with the portable
zip alongside it.

- **`packages/mi_design`** — the court archive treatment. Parchment ground, ink
  text, one oxblood accent reachable through exactly one widget, rule lines
  instead of boxes, and Source Serif 4 committed so the same document is set
  the same way on both platforms.
- **`app/`** — one Flutter application, two platform folders. Seven regions:
  interview, sitting, coverage ledger, dossier, assembly, pitch, sessions —
  plus settings and the update sheet. The dossier, the ledger and the pitch all
  render one `MiDocument` through one `DocumentView`.
- **Updating** — the app reads the rolling `dev` tag at launch, compares build
  numbers numerically, prefers the installer over the zip on Windows, and hands
  the downloaded file to the system: the package installer on Android, a silent
  install-and-relaunch on Windows.
- **The transports** — the CLI on a desktop, and `HandoverCouncil` on a phone,
  where every turn is carried by hand. Both are the same `CouncilTransport`, so
  both produce identical records.

The APK was built and its signature verified against the committed key before
any of this was pushed. The Windows installer can only be built on a Windows
host, which is what the CI job on `windows-latest` is for.

## Not started
- **The interview itself.** The gate, the module bank and the composer exist and
  are tested; what does not exist is the thing that *conducts* an interview —
  putting a composed module to a person, reading what comes back, and producing
  the restatement they approve. That is a client job, and it is the first thing
  the clients need.
- **The three reference sessions**, the evidence set, and the review cycles.
  All of them wait on the engine and the clients: every artifact must come from
  a session that actually ran.

## Next action

Run the three reference sessions for real, and capture the evidence set from
them. Everything they need now exists: the clients build, a sitting can be
driven from either transport, and the dossier, ledger and pitch render from the
stored files.

Before that, two things worth doing while the toolchain is fresh: exercise the
wide layout in a widget test (`tester.view.physicalSize`, since the default
800×600 is below the 900px gate and leaves the desktop branch uncovered), and
put a real sitting through the Android handover route end to end rather than
through a scripted double.

## Known gaps to watch

- First-round breadth is bounded by the number of interview answers, because a
  first-round direction has no map to distinguish it from its neighbours. Real
  runs at the largest tier will need the cartographer naming gaps generously.
  Recorded in decision 0005.
- The dedup threshold (`jaccard-substance-v1@0.62`) has been exercised only
  against the scripted council. The first real session is the first honest test
  of whether it is lax or strict, and changing it means a new rule id rather
  than an edit.
