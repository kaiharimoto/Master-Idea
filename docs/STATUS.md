# Status

Where the build actually is. Kept current as part of every change, because it
is the only thing that tells the next session where we were.

**Last updated:** first build session.

## Done

`packages/mi_core` — the engine, headless, analysed, formatted and green.

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

82 tests, all green: `cd packages/mi_core && dart test`.

## Not started

- **Both clients.** No Flutter work has begun. Neither is stubbed either —
  the rule that neither is a port of the other applies from the moment the
  first one starts.
- **`mi_engine`.** The session store on disk, the Claude CLI locator and
  transport, and the headless `mi` entry point. The directory layout the store
  will write is settled (`sessions/<id>/interview/`, `rounds/`, `ratings/`,
  `run_manifest.json`); nothing writes it yet.
- **The three reference sessions**, the evidence set, and the review cycles.
  All of them wait on the engine and the clients: every artifact must come from
  a session that actually ran.

## Next action

Build `mi_engine`: the session store writing the settled directory layout, and
the CLI transport implementing `CouncilTransport` the way Master Prompt invokes
Claude Code — locator, capability probe, one conversation per seat.

## Known gaps to watch

- First-round breadth is bounded by the number of interview answers, because a
  first-round direction has no map to distinguish it from its neighbours. Real
  runs at the largest tier will need the cartographer naming gaps generously.
  Recorded in decision 0005.
- The dedup threshold (`jaccard-substance-v1@0.62`) has been exercised only
  against the scripted council. The first real session is the first honest test
  of whether it is lax or strict, and changing it means a new rule id rather
  than an edit.
