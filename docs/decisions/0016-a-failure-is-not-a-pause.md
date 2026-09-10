# 0016 · A failure is not a pause, and a limit is not a failure

**Made:** while walking the whole workflow before shipping.
**Standing:** in force.

The transport had one exit for everything that went wrong: any non-zero exit
from the CLI became `CouncilPaused('rate', …, +20 minutes)`. With three
retries that is eighty minutes of silence per turn for a login that expired,
a model name the CLI does not know, or a binary that is no longer there —
none of which lift by waiting. At the end of it the angle was logged as a
dropped territory, the round carried on, and a run whose every search had
failed recorded itself as **having gone dry**. That is the one
misrecording this whole apparatus exists to prevent, arrived at by treating
two opposite things as one.

So the transport now reads what it was told before deciding what it was.

**A usage limit is waited out, and the wait is not capped.** A limit always
lifts. A run that gave up on the fourth wait would be recording the
provider's silence as the council's, which is precisely the mistake the
run-until-dry rule is about. The resume time comes off a ladder — an epoch
the provider stated, a delay it stated, a clock time it stated, the
five-hour block this sitting began in, and finally a guess — and **the rung
is stored beside the time** in the manifest, because an unattended run acts
on that time for hours with nobody watching, and a guess that reads like a
fact is how a sitting comes back early, spends a call, and pauses again.

**Everything else ends the sitting, loudly and resumably.** `CouncilUnavailable`
carries what the CLI said and reaches the client, who can fix it — the wrong
model, the expired login — and start again. Nothing is lost by stopping,
because every closed round is now on disk before the next one opens: the
sitting resumes from the barrier it reached rather than restarting. An empty
credit balance is in this group rather than among the pauses: waiting does
not buy credit.

**A stop is a third thing.** `CouncilStopped` is the client, not the provider.
It was previously signalled as a pause, which the run caught, waited out
(the deadline having already passed) and retried — so the same turn came back
on screen, three more times, while the interface believed the sitting had
ended.

## What was deliberately not added

A per-turn concurrency bound and a per-turn timeout now live on the CLI
transport. **Neither is a stop condition** and decision 0003 is untouched:
they decide how many turns are in the air and when a hung child is declared
hung, and nothing in either can end a round, narrow a breadth, or reach the
dryness decision. The bound exists because a round at the largest tier
otherwise starts some fifty `claude` processes at once, which is itself the
commonest way to provoke the limits above; the timeout exists because a hung
child holds its future forever, and on an unattended run that is
indistinguishable from a council thinking hard.
