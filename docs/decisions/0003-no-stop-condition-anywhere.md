# 0003 · No template, and no loop, carries a stop condition

**Made:** while writing `HarnessTemplate` and `CouncilRun.deliberate`.
**Standing:** in force.

The brief forbids a run ending on a timer, a token ceiling or a step count, and
forbids a template specifying one. Two things follow that are easy to undo by
accident:

1. `HarnessTemplate` has no duration field at all. Tiers do have expected
   durations — twenty minutes to six hours — and they live in `expectation` as
   prose addressed to the client. `families_test` asserts the serialised form
   carries no key naming seconds, minutes, hours, tokens or steps, so a helpful
   future addition fails there rather than silently becoming a timer.

2. `deliberate` has no maximum round count. A safety valve was considered and
   rejected: a valve that ends the run would be recorded as dryness, which is
   the exact failure the invariant exists to prevent. The loop's only exit is
   two consecutive rounds returning nothing new. A transport that never returns
   would hang the run, and that is the correct behaviour — a hung run is
   visibly wrong, where a run capped at forty rounds is invisibly wrong.

Breadth is also held constant for the life of a run rather than merely checked,
so a dryness decision can never be made on a round that looked less hard.
