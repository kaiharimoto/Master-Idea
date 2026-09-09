# 0008 · Pitch portability is a check, not a habit

**Made:** while writing `PitchPortability`.
**Standing:** in force.

The pitch is the one artifact that leaves this pair of tools entirely, and the
brief requires it to work with any model. The commonest way that breaks is not
a deliberate choice but a habit — an XML-ish tag, a tool-call idiom, a
system-prompt convention that reads as neutral prose to whoever wrote it.

`PitchPortability.tells` names the patterns and the suite asserts a real pitch
is clean *and* that the check fails on something, so it cannot rot into a
function that always returns true.
