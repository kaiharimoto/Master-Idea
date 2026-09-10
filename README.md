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

## Install it

Builds are published to the rolling
[`dev` release](https://github.com/kaiharimoto/Master-Idea/releases/tag/dev) on
every green push. The link never changes.

**Android** — download the `.apk` and open it. Android will ask once whether to
allow installs from your browser. Later builds install straight over this one
and keep every stored session, because every build is signed with the same key.

**Windows** — download `MasterIdeaSetup-*.exe` and run it. It installs for you
only, so there is no administrator prompt. SmartScreen will warn that the
publisher is unknown because the installer is unsigned: *More info*, then *Run
anyway*.

After the first install you should not need that page again — the app checks it
at launch and updates itself in one click.

**A phone cannot run a sitting unattended.** There is no Claude CLI there, so
every turn is carried by hand: the app gives you what to send and takes back
what comes of it. The records are identical either way; the difference is
whether you have to be there.

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

And both clients: one Flutter application for Android and Windows, with seven
regions — interview, sitting, coverage ledger, dossier, assembly, pitch and the
session library — set in the court archive treatment, updating themselves from
the rolling release.

Not yet done: the three reference sessions and the evidence set they are
captured from. `docs/STATUS.md` is the honest account of where the build is.

## Building and testing

The two pure packages need only the Dart SDK — no Flutter — which is what keeps
the logic that has to be right during an unattended sitting testable in
seconds.

```bash
cd packages/mi_core   && dart pub get && dart analyze && dart test   # no Flutter
cd packages/mi_engine && dart pub get && dart analyze && dart test   # no Flutter
cd packages/mi_design && flutter pub get && flutter analyze && flutter test
cd app                && flutter pub get && flutter analyze && flutter test
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
packages/mi_design/   The court archive treatment. Flutter.
app/                  The Flutter app for Android and Windows.
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
