# 0011 · The seam to Master Prompt is a pitch, read as a paste

**Made:** while wiring the two halves together.
**Standing:** in force.

The brief says the pitch prompt is the input to Master Prompt. The question is
how it gets there.

Master Prompt already has a paste box in its mission picker, for `.mpx`
bundles. That is the seam: a pitch is tried first, and a paste with no versioned
`mi-pitch` block falls through to the bundle path untouched. No file picker, no
new native code on two platforms, no protocol — and it works identically on a
phone and at a desk, which the rest of that program's transfer story already
depends on.

Three properties hold across the seam, and each is asserted by a test on the
Master Prompt side:

- **Everything arrives `proposed`.** That program's central convention is that
  only a value its user accepted may satisfy the readiness gate. A pitch is
  written by a council — a model — however carefully its client chose which
  directions to keep, so it is precisely the case the convention exists for. An
  imported mission still cannot compile until the interview confirms it.
- **The whole document travels**, not only the block. The block is a summary;
  the prose carries the integration, the reasoning and the marked assumptions.
  It is kept as a received exchange, which also means the mission has answered
  once and the interview's next turn need not re-send the whole framing.
- **The block is line-oriented and versioned.** Line-oriented so a paste cut off
  by a chat's ceiling loses one field rather than everything; versioned so a
  future grammar is *not read* by an old build rather than misread by one.

Both test fixtures are a pitch this program actually produced, run through
`mi run` and `mi select`. A hand-written fixture would drift the moment either
side changed a heading, and the seam would then be tested against a format
nothing emits.
