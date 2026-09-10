# 0015 · The design system is Master Prompt's, not a second one

**Made:** after the first build was looked at.
**Standing:** in force. Supersedes the court-archive treatment in the brief.

The brief specifies a court archive: parchment-warm ground, ink text, oxblood
for verdicts, a serif throughout. It was built that way and it was handsome.
Put beside Master Prompt it read as a different program — different ground,
different type, different everything — which for two halves of one pair that
are meant to be run side by side and hand work to each other is simply wrong.

So the system is now Master Prompt's, adopted whole: the same Inter at the same
scale, the same near-monochrome palette value for value, the same 8-point grid,
the same hairline-ruled panels, and the same `MiFocal` container for a screen
that asks one question. `treatment_test.dart` checks the tokens against the
other half's actual numbers, so the two cannot drift apart a commit at a time.

**One thing is kept from the court archive, because it earns its place.**
`MiColors.verdict` is that oxblood, reserved for verdicts and ratings. A
council's entire output is judgement, and a dossier that sets its ratings in
the same ink as its prose is one you have to read twice to find them in. It is
reachable through exactly one widget and the test reads the source to prove it.

This overrides the brief on appearance, which is the client's to decide and
which they did. The brief's *reasons* survive intact: nothing reads as a chat,
a dashboard or a blank canvas; a sitting in progress is still quiet, with
counts of things that exist and no progress bar over a total nobody can know.
