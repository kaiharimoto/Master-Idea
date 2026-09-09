# Master Idea

The Idea half of a pair. **Master Prompt** decides how a thing gets built;
Master Idea decides *what* should be built and why it deserves to exist, and
its output is the input to that one.

You bring one raw idea. It interviews you hard, once — that is the only moment
you are present — and then a council of agents goes away and deliberates
unattended for as long as the idea warrants, proposing directions, arguing
them, and rating them independently. You get back a case file: every direction
with its rating, the reasoning, the dissent behind it, a map of the idea space
showing what was explored and what was deliberately left, and a pitch prompt
built from the directions you chose.

It works for any creative project — an essay, a story, a song, a program.

## What exists today

The engine, headless and provable:

- The council: ten seats, twelve exploration angles, six rating dimensions,
  four harness templates, seven domain profiles, fifteen interview modules.
- Rounds as barriers, with the angles inside a round fanning out concurrently
  and blind to each other, and each direction pipelining through challenge and
  independent rating as soon as it exists.
- The three hard invariants — traceability, independent rating with recorded
  dissent, and run-until-dry with logged drops — enforced during a run and
  checkable afterwards by a self-test suite that runs against a stored session
  and nothing else.
- Pure renderers over a stored session: the dossier, the coverage ledger, and
  the pitch prompt, all of which work with the council unreachable.

Not yet built: the two clients (Android and Windows desktop), the on-disk
session store, and the Claude CLI transport. `docs/STATUS.md` is the honest
account of where the build is.

## Building and testing

Only the Dart SDK is needed for everything that exists today. No Flutter.

```bash
cd packages/mi_core && dart pub get && dart analyze && dart test
```

`dart format` is a CI gate. Run it before pushing.

## How the two halves join

A finished session exports a pitch prompt: a launch document that carries the
directions you selected and the integration computed across that set. It is
plain prose that works in front of any model, and it ends with a small
`mi-pitch` block that Master Prompt reads to open a mission without you
retyping anything. The values arrive there **proposed**, never confirmed —
Master Prompt's rule that only a value you accepted can satisfy its readiness
gate holds across the seam.

## Layout

```
packages/mi_core/     The council, the session record, the invariants, the
                      renderers. Pure Dart: no Flutter, no dart:io.
packages/mi_engine/   The on-disk session store, Claude CLI discovery and
                      invocation, and the headless entry point. dart:io only.
docs/decisions/       The contemporaneous decision log, and parity.md, which
                      records every place this build matches Master Prompt's
                      architecture and every place it deviates.
critics/              The ten critic prompts, the closed rating vocabularies
                      and the deduction table, committed before the first
                      review cycle.
sessions/             Stored sessions. Nothing here needs an account or a
                      server to reopen.
evidence/             The fixed artifact set, captured identically every cycle.
```
