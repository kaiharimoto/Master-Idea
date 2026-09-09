# 0010 · Every council turn is a fresh one-shot call

**Made:** while writing `TurnPlanBuilder` and `CliCouncil`.
**Standing:** in force. **Deviation from Master Prompt's CLI pattern**, also in
`parity.md`.

Master Prompt's `CliConversation` opens a session with a pinned id and resumes
it on every turn after, which gives the desktop the same *one continuing chat*
property its copy-paste transport assumes. That is right there: an interview is
a conversation, and round-to-round context is the value.

It is wrong here. Independent rating is a hard invariant, and it is not
satisfied by seating a different agent: an assessor whose conversation carried
the prospector's case for a direction is rating the advocacy — the invariant
broken by the transport, with no code passing anything. So there is no
`--session-id` and no `--resume` in `TurnPlanBuilder`, and `turn_plan_test`
asserts their absence rather than leaving it to habit.

What is kept from that pattern: the turn runs in a directory of the council's
own, so a `CLAUDE.md` in the project the idea is *about* does not join
uninvited; the permission mode is pinned to `default` and never the client's
run setting, because a seat arguing about what an idea could be needs no tools;
and effort degrades downward only.

The cost is real — every turn re-sends the brief and the angle — and it is the
right cost. A cheaper run whose verdicts cannot be trusted is not cheaper.
