# Working on Master Idea

Read this first, then `docs/STATUS.md`. Feedback on this project arrives as
conversation rather than as tickets, so nothing about where we were survives a
session boundary except what is written down in those two files.

## What this is

The Idea half of a pair. Master Prompt (github.com/kaiharimoto/Master-Prompt)
decides how a thing gets built; this decides what should be built and why it
deserves to exist. A hard interview, then a council of agents deliberating
unattended for as long as the idea warrants, then a case file and a pitch
prompt that is the opening input to Master Prompt.

The client is interviewed once and reads a dossier at the end. **Their work is
at the beginning and the end, never in the middle.** Everything in the design
follows from that: the run never waits on input, the ledger makes the
completeness claim auditable rather than asserted, and every judgement is
attributable to the seat that made it.

## Layout

```
packages/mi_core/     Council, session record, invariants, renderers.
                      Pure Dart. No Flutter, no dart:io.
packages/mi_engine/   Session store on disk, Claude CLI transport, headless
                      entry point. dart:io only. No Flutter.
packages/mi_design/   Master Prompt's design system, in the same Inter at the
                      same scale, plus one reserved colour. Flutter.
app/                  The Flutter app for Android and Windows.
```

**There is no pub workspace, deliberately** — the same decision Master Prompt
made and recorded. A workspace that included Flutter packages means
`dart pub get` needs the Flutter SDK, which breaks CI for the pure packages and
destroys the property they exist to have.

## Commands

```bash
cd packages/mi_core   && dart pub get && dart analyze && dart test   # no Flutter
cd packages/mi_engine && dart pub get && dart analyze && dart test   # no Flutter
cd packages/mi_design && flutter pub get && flutter analyze && flutter test
cd app                && flutter pub get && flutter analyze && flutter test
```

`dart format` is a CI gate. Run it before pushing.

## The three invariants, and why they are structural rather than checked

They are enforced in the shape of the code, and the suite in
`invariant_suite.dart` is the second line rather than the first.

**Traceability.** A direction may cite an interview answer or a ledger gap
named in an *earlier* round. `CouncilRun._refuse` rejects anything else during
the round, so an unsourced direction never reaches the dossier at all. Two
directions may share an answer only if each also names a gap of its own, and
the gaps must differ — which is why the cartographer names several gaps per
barrier rather than one. A map that names one gap a round cannot tell two
directions apart, and the suite refuses both of them.

**Independent rating.** No role holds both `propose` and `rate`
(`families_test` asserts it), so a self-judging seat cannot be created by
accident. Independence is at *instance* level: `assessor#2.4` is the identity
on a verdict, not `assessor`. And it is not enough to seat a different agent —
`RatingContext.forDirection` is the only way to build what a rater sees, and it
carries the direction and the constitution and nothing about where either came
from. The text it produced is stored with the verdict, so an auditor reads what
the rater read.

**Run until dry.** The loop in `CouncilRun.deliberate` has exactly one exit:
two consecutive rounds that returned nothing new. **There is no step cap, no
token ceiling and no timer, and the absence is deliberate** — a run that can be
ended by a counter will be, and 'ran until the cap' would then be recorded as
'ran dry'. Breadth is held constant for the life of a run so that a dryness
decision is never made on a narrower round. A provider limit is a `CouncilPaused`
exception, never an empty reply: an empty reply is evidence of dryness and a
rate limit is the opposite of evidence.

## Traps, all of them found the hard way

**The accept path must not contain an `await`.** Angles run concurrently and a
real council converges constantly — every angle proposing the same obvious idea
from a different direction. Deduplication and acceptance happen in one
synchronous stretch in `_workAngle`; a yield in the middle lets two angles both
accept the same proposal and the dossier silently doubles.
`council_run_test.dart` holds that as a contract by having every angle propose
the same idea first and asserting exactly one survives.

**The wire format is line-oriented and must never become JSON.** These blocks
are written mid-run by a model that can be cut off at any character. A
truncated JSON object loses the whole block; a truncated line grammar loses one
field. A round that returns nine good directions and one half-written one keeps
the nine — `reply_parser_test.dart` proves it, and the parser keeps a block
whose closing `end` never arrived for the same reason.

**`mi-none` is a standalone marker, not a block with fields.** It was being
dropped by the parser, because the end-of-input path only kept blocks that had
fields. 'My angle is exhausted' is the single most consequential thing a seat
can say — it is what takes a run to dryness — and it was the one reply the
parser could not read.

**A template may not carry a stop condition.** `families_test` asserts the
serialised form of every harness template has no key naming seconds, minutes,
hours, tokens or steps. Tiers do have expected durations; they live in
`expectation` as prose, because an expectation for the client is not an
instruction to the run.

**A dryness decision names both rounds and both angle sets.** Not for the
record's sake: the check that the second round was not narrower than the first
is the only thing standing between run-until-dry and a timer with better
manners.

**Ordinal words, never numerals.** A number invites averaging, and averaging is
how dissent disappears. Vocabularies are closed, ordered, committed before the
first review cycle in `critics/vocabularies.md`, and every rating record names
the vocabulary it drew from so a verdict read in isolation still means
something. The ordering exists only in code, for sorting; it never reaches the
page.

**Dissent that agrees is worse than no dissent.** A dissent recording the same
verdict it dissents from, or holding no reason, is dissent manufactured to
satisfy the anti-diplomatic-ratings check — rigour-shaped and information-free.
The suite fails it.

**A drop with no reason is a silent truncation wearing a label.** The
cartographer is not permitted one: if a territory comes back dropped with no
reason, the run writes the only honest reason available — that none was given —
rather than storing an empty string that reads as fine.

**The renderers must never reach back into the council.** They are pure over
the stored session, which is what lets a session be reopened next month with no
API key. `render_test.dart` proves it the only way it can be proven: by having
a transport available that throws if anything touches it.

## The clients

**One application, two platforms, and the transport is the only real
difference.** Every region is one widget tree. The dossier, the ledger and the
pitch all arrive as an `MiDocument` from the core and are laid out by one
`DocumentView`, so neither platform decides for itself what a verdict looks
like — parity is a property of there being one of them.

**The Android client cannot run a sitting unattended, and never says it can.**
There is no CLI on a phone, so `HandoverCouncil` carries each turn out by hand
and takes the reply back. It implements the same `CouncilTransport` the CLI
does and the same `CouncilRun` drives it, so a hand-carried sitting produces
identical records — but six hours of it is six hours of a person copying, and
claiming the desktop's autonomy for that would be the one platform difference
that matters being papered over.

**The design system is Master Prompt's, deliberately.** Same Inter, same
near-monochrome palette, same 8-point grid, same hairline-ruled panels, same
`MiFocal` shape for a screen that asks one question. The two programs are one
family, run side by side, and hand work to each other; a different look would
be a claim that they are unrelated. `treatment_test.dart` checks the tokens
against the other half's actual numbers rather than against a memory of them,
so they cannot drift apart one commit at a time.

**One colour is added, and exactly one widget may touch it.**
`MiColors.verdict` is oxblood, for verdicts and ratings and nothing else — a
council's entire output is judgement, and a dossier that sets its ratings in
the same ink as its prose is one you have to read twice to find them in.
`MiVerdict` is the only widget that reaches it, and the test reads the source
to prove nothing else does. Material is handed *ink* as its `primary` for the
same reason: a stock widget reaching for `primary` would otherwise paint
something verdict-coloured that is not a verdict.

**The font is committed and the theme names it package-qualified.**
`packages/mi_design/Inter`, not `Inter` — the unqualified name resolves to
nothing and falls through to the platform sans *silently*, which sets the same
screen in Roboto on Android and Segoe on Windows with no error anywhere.

**Look at the screens, do not reason about them.**
`flutter test --tags shots --update-goldens` renders the real regions to
`app/test/shots/`. It found two defects on its first run — a section header
printing `null /` and a dissent label printing its own interpolation — and
neither would ever have failed an assertion. The shots are skipped in an
ordinary run, because font rasterisation differs between machines and pixel
comparison on a runner goes red for reasons that have nothing to do with the
design.

**CompanyName and ProductName in `Runner.rc` are load-bearing.**
`path_provider_windows` builds `getApplicationSupportDirectory()` as
`RoamingAppData\<CompanyName>\<ProductName>`, read out of the running exe's
VERSIONINFO at runtime. Editing either string silently relocates every stored
session and the app starts up empty with nothing saying why.

**`app/android/dev-keystore.jks` is committed on purpose.** Every build is
signed identically so a new one installs over the last instead of forcing an
uninstall that would take the user's sessions with it. It is public, worthless
as a secret, and must never sign a Play Store release; CI asserts the
certificate fingerprint after every APK.

**Widget tests must not touch the filesystem.** Use `Library(inMemory: true)`.
Real writes cannot complete in the tester's fake-async zone, so a test that
persists either hangs or races depending on machine load. Use a plain `test()`
for anything about storage.

**Widget tests default to 800×600**, which is below the 900px wide gate — so
every test here exercises the narrow layout unless it sets
`tester.view.physicalSize`. The wide branch of `home.dart` is uncovered
otherwise, and that is the branch a desktop actually runs.

## Conventions

- Every family member must execute in a stored session. An angle no session
  ever searches is not an unused option, it is a family member that never ran —
  which is why `CouncilRun.angleSetFor` rotates through the whole catalog even
  at the narrowest breadth, and a test walks twelve rounds to prove it.
- A domain profile may say where to start and never where to stop. Favoured
  angles lead the first round and nowhere else; a profile that could switch an
  angle off would be a way of quietly narrowing the search.
- The council never decides what ships. The pitch contains only what the client
  selected in Assembly — including the filter that drops an integration pair
  naming a direction the client has since dropped.
- Tests assert behaviour and say why in the `reason:`, rather than restating
  the assertion.
- Every judgement call made in the client's absence goes in
  `docs/decisions/` at the moment it is made. A decision log written at the end
  as a summary is a failure condition, not a late delivery.

## The mark

`tool/make_icon.py` generates the icon and is committed alongside what it
produces. **The letter is I, and Master Prompt's is P** — same ink, same Inter,
same hairline rule under the initial, because they are one family and the
initial is the only thing that should tell them apart in a taskbar. The two
scripts are the same file with one constant changed; keeping them in step by
hand is the point.

## The loop

The user tests real builds and reports in chat. Fix breakage, crashes and
obvious bugs directly; discuss anything that changes behaviour or appearance
first. Keep `docs/STATUS.md` current as part of the change.
