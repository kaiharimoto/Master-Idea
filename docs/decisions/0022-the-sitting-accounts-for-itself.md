# 0022 · The ground is mapped before it is searched, and the sitting accounts for itself

**Made:** after a client ran an assize, came back to it, and could not tell what
had happened.
**Standing:** in force.

The screen said **"What the council has been doing: Nothing yet."** Above it:
ninety-six directions, five hundred and seventy-six verdicts, one thousand two
hundred and seventy-two model calls. Every figure was correct — 24 propose calls
plus 96 directions at 13 calls each is 1,272 exactly — and none of it was
visible.

Three separate defects produced one experience, and they share a shape:
something true was on disk, and nothing honest was reading it.

## 1. The map is drawn before the first angle is seated

The cartographer ran when `round % roundsPerBarrier == 0`. At an assize that is
three, so the first two rounds searched with no map at all and every direction
in them could cite nothing but an interview answer. Two directions sharing an
answer must each name a gap of their own; with no gaps there are none to name.
Ninety-six directions over sixteen interview modules, every one accepted during
the round and rejected by the suite afterwards, with the calls already paid for.

The first attempt was to map at the **end** of round one. It does not work, and
the attempt is worth recording because the reason is the whole point: a gap may
only be cited by a direction from a *later* round than the one that wrote it, so
a map written at the end of round one can never source a round-one direction.
And round one at an assize puts forward forty-eight directions against sixteen
answers. No council can tell them apart. The seat was not late, it was missing.

So the map is now drawn **before the loop**, in round zero, from the brief and
the medium alone — which is all it ever needed. The cartographer says what
ground the idea covers, not what the council has found on it. Then round one and
every `roundsPerBarrier` after it, as before.

Decision 0005 recorded this as a bound on first-round breadth: *"with no map
yet, a first-round direction can only be distinguished by which answer it came
from, so first-round breadth is bounded by the number of interview answers. That
is a real constraint on the tool and it is the right one."* It was not a
constraint. It was a missing call, and it cost an assize.

**Why the map and not a stricter refusal.** The obvious alternative is to make
`CouncilRun._refuse` enforce the shared-answer rule during the round. It cannot:
the rule is a property of the whole set of directions kept so far, and enforcing
it inside `_workAngle` would mean concurrent angles reading a set the others are
writing — inside the one stretch that must contain no `await`. Giving the seats
distinct gaps to cite removes the condition; checking for it would only move the
failure earlier. The suite stays the second line, where it belongs.

**The opening map is stored before round one opens**, through the same barrier
callback. A sitting killed during its first round would otherwise buy the same
map twice.

## 2. Usage was read from a key nothing writes

`CliCouncil._read` took `usage` from the root of every event and added them up.
The real CLI puts usage inside `message` on assistant events and at the root of
the `result` event only, so that read matched exactly one thing: the result
event's `input_tokens`, which is the **uncached remainder**. Two tokens against
a prompt of nine thousand characters. The client's manifest said 2,544 input
tokens across 1,272 calls — exactly 2.0 each — beside 761,659 out.

Now: the result event's usage is the turn's own roll-up and wins when present;
assistant usage, keyed by message id and overwritten rather than added, is the
fallback for a stream cut off before the roll-up arrives. Two accumulators, so a
build that emits both cannot count the same tokens twice. Keying by id matters
on its own: one message can be reported several times across a tool loop, and
adding every report counts the prompt every time.

`cache_creation_input_tokens` and `cache_read_input_tokens` are recorded as
their own fields on `CouncilReply`, `ModelCall` and `RunManifest`. **Not summed
into `tokensIn`**: the three are priced differently, a cache read is a fraction
of fresh input and a write is more than it, and a sum cannot be taken apart
again by anyone reading the manifest later. A session written before any of this
reads them as zero, which is the truth about it.

The same rewrite fixed a second bug in the same function. The result event
repeats the whole final assistant message, and `_read` was appending both — so
the parser saw every block twice and the deduplicator refused each direction
against its own first copy. One event's text, taken once.

**The lesson, which is the expensive one.** None of this was catchable, because
`tool/fake_council.dart` emitted usage at a nesting level the real CLI never
uses, omitted the cache fields, and put no usage on its result event at all. The
only assertion was `tokensOut > 0`; `tokensIn` was asserted nowhere. **A double
whose shape is invented tests the code against the double.** The fake now emits
the real shape, with `MI_FAKE_TOOL_LOOP` and `MI_FAKE_NO_RESULT` for the
branches a single-event fake cannot reach, and the new tests assert `tokensIn`,
the cache fields, and — the one that would have caught it — that a whole run
reports more input than output.

## 3. The screen reads the stored rounds

Every closed round is on disk in full: which angles were seated, what each
returned, what was refused and why, what duplicated what, when it opened and
closed. The sitting screen rendered `Sitting._events`, an in-memory list that
`begin()` clears and closing the app destroys. That is the whole of "Nothing
yet."

`RoundAccount` and `AngleAccount` in `render/` are pure over a stored round plus
the manifest, and turn ids into words — `angleByIdOrNull`, written for display
code and until now called nowhere, plus new `roleByIdOrNull` and
`AgentInstance.parseOrNull` so a session written by another build prints rather
than taking the screen down. **One computation, two readers:** the coverage
ledger and the client's screen both say what a round did, and two
implementations of one funnel drift. An exported record disagreeing with a live
screen about the same round is worse than either being absent. It also recovered
something the ledger was losing: refusals were flattened across all rounds, and
which round each came from was discarded.

## 4. What is owed is a floor, and there is no ceiling anywhere

`LowerBounds` says two things: the round the ground is next mapped at, and the
round before which the sitting cannot end. Both derived from the rules
themselves, both saying there is more work and never less.

A run ends when two consecutive rounds keep nothing new, which is unknowable in
advance. So the arc of what each round kept is drawn instead — the approach to
nothing *is* the progress, and it can be shown without anyone predicting
anything, because the bars are what already happened and the line beneath them
states the rule. No percentage, no fraction, no estimate, on the screen or in
the prose. Decision 0003 restated at the one place in this program where
breaking it was tempting.

`CouncilRun` cannot see `LowerBounds`, and a test reads its source to prove it.
An arithmetic the loop can read is an arithmetic the loop can be made to obey,
and then "ran until the number" would be written down as "ran dry".

## 5. The audit runs at barriers, and says what it cannot yet know

`InvariantSuite.run` was already pure over a stored session and already in the
app behind a button on the dossier. It now runs at every barrier — never per
event, and the reason is not cost: mid-round a direction kept a second ago has
not been judged yet, and the suite would correctly report it unrated, a finding
that is not a finding flashing on screen for the minute it takes to rate it.

`_runUntilDry` always reports *"the run has no dryness decision"* before a run
ends. A panel showing that as a failure would be wrong every second of every
live sitting and would teach the client to stop reading it. So the three
invariants are shown separately, and run-until-dry reads **"decided when the
sitting ends"** until there is a decision. The tag is `warning`, never `danger`:
a healthy sitting carries findings that later rounds close.

A session that ran before this change keeps its findings — the opening map
cannot reach backwards. The panel says which round that session's map was first
drawn in rather than letting the app take credit for a fix it did not apply.

## 6. Charts entered the design system, with no new colour

Four primitives in `mi_design`: columns, labelled bars, a three-part split bar,
and a fan-in indicator. `MiColors.verdict` appears in none of them — a council's
judgements are the one thing set in that ink and a bar is not a judgement — and
the source-reading test that holds that rule now scans every file in `lib/src`
rather than only the one it was written against.

**Nothing carries meaning in colour**, which a near-monochrome palette could not
do anyway: identity is position plus a written label on every mark, which is
also what makes these readable under any colour vision and in forced colours.

The one ramp, in the split bar, was **measured rather than chosen**. Four
neutral steps fail: the fourth is a border token at 1.54:1 against the surface,
a segment nobody could see. Three — `ink`, `inkMuted`, `inkFaint` — pass every
check in both themes, light-end contrast 2.67:1 and 3.40:1. So the round funnel
is four separate bars on a shared scale rather than one stacked bar, which needs
no ramp at all and reads as a funnel by shape.

The one honest denominator in the whole program is a round's angle fan-in: the
breadth is decided before the round opens. That is the only place a fraction is
drawn, and nothing else gets one.
