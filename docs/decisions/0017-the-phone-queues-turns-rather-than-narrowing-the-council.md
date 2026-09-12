# 0017 · The phone queues turns rather than narrowing the council

**Made:** while walking the whole workflow before shipping.
**Standing:** in force.

A round fans out four angles at the smallest tier and pipelines every
direction through challenge and rating, so a second turn is always in the air
while the first is still on screen. `HandoverCouncil` answered that second
turn with a `StateError` — and a `StateError` is not a `CouncilPaused`, so it
left the run entirely. The first hand-carried turn of any sitting killed the
sitting, **after** the client had already copied it into a chat, waited for
the reply, and brought it back.

Two ways out. Narrow the council when the transport is the hand — run one
angle a round — or queue.

**Queued.** Breadth is a property of the search, and the dryness rule is a
statement about consecutive rounds *at the same breadth*. A transport that
narrowed the council would make "ran dry" mean something different on a phone
than on a desktop while both wrote the same word into the same manifest, which
is the one thing the two clients may never do. The transport decides how a
turn travels; it may not decide how wide the council looks.

The cost is real and is now stated on screen rather than discovered: a hearing
is a few hundred turns, and on this route every one of them is a person
copying. The panel says how many are queued behind the one in hand and how
many have been carried, because a client owed that arithmetic should be given
it before they start rather than at turn ninety.

Two things follow from the same reasoning:

**A stop is terminal.** It fails every queued turn with `CouncilStopped` and
refuses every later one. Signalled as a pause, it was waited out and retried,
so the same turn reappeared while the interface believed the sitting had
ended.

**A reply is read before it is accepted.** What comes back has been through a
person, a clipboard and whatever the chat app did to the formatting, and the
run cannot tell a truncated paste from a seat with nothing left to say. One of
those is what takes a run to dryness. So the panel parses first, says what it
found, and offers to take the paste again.
