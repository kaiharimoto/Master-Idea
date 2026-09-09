# Status

Where the build actually is. Kept current as part of every change, because it
is the only thing that tells the next session where we were.

**Last updated:** the session that built the engine and the headless spine, and
joined the two halves of the pair.

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

## Not started

- **Both clients.** No Flutter work has begun. Neither is stubbed either —
  the rule that neither is a port of the other applies from the moment the
  first one starts.
- **The interview itself.** The gate, the module bank and the composer exist and
  are tested; what does not exist is the thing that *conducts* an interview —
  putting a composed module to a person, reading what comes back, and producing
  the restatement they approve. That is a client job, and it is the first thing
  the clients need.
- **The three reference sessions**, the evidence set, and the review cycles.
  All of them wait on the engine and the clients: every artifact must come from
  a session that actually ran.

## Next action

Start both clients at once, from the thin end-to-end spine the brief asks for:
one smallest-tier session across all seven regions on Android and Windows
together, unstyled, before any treatment is applied. `mi_design` first — the
court-archive tokens, with the accent reachable only by a verdict block — then
the seven regions against `MiDocument`, which both clients render rather than
each deciding for itself what a verdict looks like.

Neither client may be stubbed while the other is built. That is a failure
condition in the brief, and it is also the only way parity survives contact
with a deadline.

## Known gaps to watch

- First-round breadth is bounded by the number of interview answers, because a
  first-round direction has no map to distinguish it from its neighbours. Real
  runs at the largest tier will need the cartographer naming gaps generously.
  Recorded in decision 0005.
- The dedup threshold (`jaccard-substance-v1@0.62`) has been exercised only
  against the scripted council. The first real session is the first honest test
  of whether it is lax or strict, and changing it means a new rule id rather
  than an edit.
