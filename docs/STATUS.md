# Status

Where the build actually is. Kept current as part of every change, because it
is the only thing that tells the next session where we were.

**Last updated:** the session that drew the sitting. A client came back to an
assize and read "What the council has been doing: Nothing yet" over ninety-six
directions and twelve hundred model calls. Decision 0022: the ground is mapped
before it is searched, usage is read from the key the CLI actually writes, and
the screen reads the rounds on disk instead of a list it throws away.

## Done

`packages/mi_core` — the engine, and `packages/mi_engine` — the store, the
Claude CLI transport and the headless entry point. Both analysed, formatted and
green: 108 tests and 50. The clients are analysed, formatted and green too:
14 in `mi_design` and 52 in `app`, where there were 30 before this walk and
none at all over the sitting, the assembly or the interview past its second
question.

- **Families.** Eleven council roles, twelve exploration angles, six rating
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
  proposal; **the session written at every barrier**, so a run killed at hour
  four loses the round it was in and nothing else; every model call recorded in
  a machine-written manifest.
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
mi rm     sessions/ <id>               # delete a stored session
```

Every step of that is tested as a real subprocess, because a command whose exit
code is wrong is a check that silently always passes. The council in those
tests is a compiled fake binary that refuses what the real one refuses — a
missing `--print`, an unknown flag, stream-json without `--verbose`, a stdin
that never reaches EOF — and that can be told to hang, to fail without a limit,
or to report one in any of the wordings a real limit arrives in.

## What the pre-ship walk changed

Recorded here because the reasons are in `docs/decisions/0016`–`0020` and the
shape of them belongs where the next session will look.

- **A failure is not a pause.** Every non-zero exit from the CLI used to become
  a twenty-minute rate limit, so a login that had expired cost eighty minutes
  of silence per turn, dropped the angle, and let the run record itself as
  having gone dry with nothing in it. A usage limit is now waited out
  uncapped against a reset ladder whose rung is stored beside the time;
  anything else ends the sitting with the reason attached, resumably.
- **The phone can finish a session.** The handover transport refused a second
  concurrent turn, which killed the first round of every hand-carried sitting;
  turns queue now. Assembly asked for the CLI directly, so a phone stopped one
  step short of the pitch; it goes through the same transport as everything
  else.
- **The interview survives being interrupted**, its answers can be corrected
  before the gate, its unknowns withdrawn, and the gate says what it still
  wants before the button is pressed rather than after. A new seat, the clerk,
  drafts the restatement and the scale verdict that were previously string
  concatenation and a keyword search.
- **A second idea can be convened** without restarting the app, the back
  gesture steps through the regions instead of leaving, and a session can be
  deleted.
- **The output can leave.** Dossier, ledger and pitch all copy and save, and
  the dossier runs the invariant suite in the app.
- **The ledger accounts for the run.** Council time against wall clock, every
  pause with how its resume time was arrived at, the model calls, the route,
  and each round's proposed-against-kept — all of it was in the manifest and
  none of it reached a page.
- **Settings tests the connection by using it.** Locating the binary proves
  nothing about an expired login or a model name the CLI does not know, which
  are the two failures that actually end a sitting. It now puts a turn through
  and reports what came back, against the values as typed.

## What the first real sittings changed

- **The CLI speaks on stdout.** Under `--print` its own failures — a usage
  limit above all — arrive as a `result` event with `is_error` set, and
  stderr stays empty. The transport read stderr alone, so a spent block ended
  the sitting as `The CLI exited with 1: ` with nothing after the colon, and
  pressing Resume inside the same block did it again. Both streams are read
  now, an exit that said nothing says so, and the fake council reports a limit
  both ways.
- **The client can pause.** `CouncilRun.hold()` is a gate in front of the
  transport: turns already out finish and are kept, turns behind it wait, and
  `release()` continues the round exactly where it was. Recorded on the
  manifest as a `Hold`, excluded from council time, invisible to dryness.
  Not a stop condition — a held run makes exactly the calls an unheld one
  does, and the test says so.
- **The sitting screen reads the run, not the store.** Directions, verdicts,
  calls and tokens move as they happen; the round in progress is counted as
  far as it has got; what is out with the council is named by purpose; and
  the arithmetic of a round is written on the screen in the run's own
  constants. The ledger costs each round in calls. The diagnostic log carries
  the shape of the sitting and every round, pause, hold and stop.

## What the sitting screen shows now

Drawn rather than listed, because counts that do not move are how a running
council looks like a hung one.

- **A hero figure** — directions held, with verdicts, calls and tokens under it.
- **What each round kept**, as columns. A sitting ends when two rounds in a row
  keep nothing, so the approach to zero *is* the progress and it can be shown
  without predicting anything. There is no percentage anywhere and there never
  may be: decision 0003, and a test walks every text node on the screen to hold
  it.
- **The round under way** — angles back against the breadth seated, which is the
  one honest denominator in the program, and what is out with the council right
  now named by what it is doing.
- **Where the thinking has gone** — clusters by weight, and the ground entered,
  left aside and still open.
- **Kept most recently**, by title. A counter climbing says the machine is
  running; the titles say what it is running toward.
- **The audit as it stands**, recomputed at every barrier, each invariant
  separately, with run-until-dry reading "decided when the sitting ends" rather
  than failing every second of a live run.
- **Round by round**, from the stored rounds, with each round's funnel.

## The three fixes underneath it

- **The ground is mapped before the first angle is seated.** The cartographer
  ran every `roundsPerBarrier` rounds, so an assize searched two rounds with no
  map and every direction in them could cite nothing but an interview answer —
  ninety-six over sixteen, all accepted during the round and rejected by the
  suite afterwards. Mapping at the *end* of round one does not fix it: a gap may
  only be cited from a later round than the one that wrote it. The map is drawn
  in round zero, from the brief alone.
- **Usage is read from the key the CLI writes.** It was read from the root of
  every event, which matched only the result event's uncached remainder: two
  input tokens per call against nine-thousand-character prompts. Cached input is
  counted now and kept in its own fields, because a cache read is not priced
  like fresh input and a sum cannot be unfolded. The fake emitted an invented
  shape, which is why a whole assize ran green.
- **The screen reads the stored rounds.** `RoundAccount` is pure over a stored
  round and the manifest, and the coverage ledger reads the same one, so an
  export and a live screen cannot disagree about a round.

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

- **`packages/mi_design`** — Master Prompt's design system, adopted whole, plus
  one added colour: `MiColors.verdict`, an oxblood that exactly one widget may
  touch.
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

**The clients are published and installable**, at
<https://github.com/kaiharimoto/Master-Idea/releases/tag/dev>. The publish job
fires from the default branch or any `claude/*` development branch: it used to
name one branch by name, so every session after the one that wrote it built
green and published nothing.

Both workflows now take their version and build number from one script, since
`github.run_number` counts per workflow and a tagged release was numbered off a
different counter than the `dev` builds the updater compares it against. The two
constants they both pin — the Flutter version and the keystore fingerprint —
are compared against each other by a job, because a copy that drifts asserts
nothing.

## Not started

- **The three reference sessions**, the evidence set, and the review cycles.
  Every artifact must come from a session that actually ran, and none has.
  `sessions/` and `evidence/` are empty.

## Next action

Run the three reference sessions for real, and capture the evidence set from
them. Everything they need now exists.

Two things are worth doing with a real device in hand rather than in a test:

- **Put a whole sitting through the Android handover route.** The queue, the
  stop, the reply preview and the hand-carried integrator are all covered by
  widget tests now, but nobody has yet carried two hundred turns by hand and
  found out what that is actually like.
- **Provoke a real usage limit on the desktop** and watch the resume. The reset
  ladder is tested against every wording the fake produces; the real one is the
  first honest test of whether those wordings are the wordings.

## Known gaps to watch

- **First-round breadth was never bounded by the number of interview answers.**
  Decision 0005 recorded that as a real constraint on the tool; it was a missing
  cartographer call, and it cost an assize — forty-eight first-round directions
  over sixteen answers, all rejected by the suite after the calls were paid for.
  The ground is mapped in round zero now, so a first-round direction has gaps to
  cite like any other. What stands from 0005 is the rule itself: a map that
  names one gap a barrier cannot tell two directions apart, and a run whose map
  is thin will fail its own invariant rather than quietly produce directions
  nobody can distinguish. Superseded by decision 0022.
- The dedup threshold (`jaccard-substance-v1@0.62`) has been exercised only
  against scripted councils. The first real session is the first honest test of
  whether it is lax or strict, and changing it means a new rule id rather than
  an edit.
- The concurrency bound on the CLI transport defaults to four turns at once.
  It is a setting, and the right number is a fact about the machine and the
  provider that only a real run will produce.
