# 0021 · A pause is the client's, a limit is on stdout, and a round is costed in the open

**Made:** after the first real sittings, reported in chat as "burning through
tokens", "stopped at round 3", and a diagnostic log whose only two lines of
substance read `The CLI exited with 1: ` with nothing after the colon.
**Standing:** in force.

## What the log actually said

Nothing, and that was the finding. Decision 0016 made the transport read what
the CLI said before deciding whether a failure was a limit — and it read
**stderr alone**, on the recorded belief that limit text could never reach the
stdout JSON stream. Under `--print --output-format stream-json` the real CLI
does the opposite: its own failures arrive on stdout as a `result` event with
`is_error` set and the reason in `result` — `Claude AI usage limit reached|
<epoch>` — and stderr stays empty. So a spent five-hour block produced an
exit code of 1, an empty account, and `CouncilUnavailable`, which by 0016 ends
the sitting resumably. The client saw a failure with no reason, pressed Resume
three hours later inside the same block, and saw it again.

The transport now reads both streams, and says so when neither said anything.
The fake council reports a limit both ways, and the suite proves that the
stdout shape becomes a pause with the provider's own reset time rather than a
failure with nobody's.

## A pause is the client's, and it is not a stop

The client asked to pause a sitting because the calls are theirs to pay for.
The existing Stop loses the round in progress — at the largest tier, up to an
hour of paid calls — which is the wrong instrument for "not right now".

`CouncilRun.hold()` closes a gate that every call passes through on its way
to the transport. Turns already out finish and are kept, because a reply
already paid for is not made cheaper by throwing it away; turns behind the
gate wait; `release()` opens it and the round continues exactly where it was.
It is transport-agnostic, so it works on the phone as it does on the desktop.

**It is not a stop condition, and decision 0003 is untouched.** A hold ends
nothing, narrows nothing, and is invisible to the dryness decision: the round
it interrupts completes, with every angle it seated, after release. The run
test proves a held run makes exactly the calls an unheld one does. It is
recorded — as a `Hold` on the manifest, deliberately a different type from
`LimitPause`, because it means the opposite thing: a limit is the provider
stopping the council and a hold is the client asking it to wait. Both are
excluded from council time; only a limit is read by the invariant suite as a
threat to dryness, because only a limit can leave a round with less searching
in it than it was seated for.

A stop while held releases the gate after closing the transport, so the
waiting turns reach it and are refused, which is how the run ends. Left
held, they would wait on a completer nobody completes.

## The round is costed in the open

The client could not tell what the sitting was doing, and the screen was
built not to say: counts fed from the store, which moves only at barriers,
so a round of eleven hundred calls showed as one hour of four numbers not
moving. Now:

- The screen reads the session **as the run has it**, so directions, verdicts,
  calls and tokens move as they happen.
- The round in progress is counted as far as it has got — angles back of the
  breadth seated, directions kept and judged, calls made, and what is out
  with the council at this instant, by purpose. Counts of things that have
  happened, never a fraction of a total; the only "of" on the screen is the
  breadth, which is the one total that is known.
- The arithmetic of a round is stated on the screen in the run's own
  constants (`wantedPerAngle`, `callsPerDirection`, `mostCallsInRound`) so
  the explanation cannot drift from the code. It is an expectation, and
  nothing reads it as a limit.
- The ledger costs each round in calls, from the manifest's timestamps.
- The diagnostic log records the shape of the sitting when it opens and
  every round, pause, hold and stop — the lines that were missing between
  "Started" and the failure.

## What was deliberately not added

A token ceiling, a cost cap, or a "stop after this round". Each is a stop
condition wearing a budget, and 0003 says why none may exist. The pause is
what a client who is watching the meter gets instead: it costs nothing, loses
nothing, and can stand for as long as they like.
