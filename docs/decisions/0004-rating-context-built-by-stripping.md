# 0004 · A rater's context is built by stripping, in one place, and stored

**Made:** while writing `RatingContext`.
**Standing:** in force.

Seating a different agent does not make a rating independent. An assessor told
who proposed a direction, or handed the proposer's case for it, is rating the
advocacy — the invariant broken by transport rather than by code, which no
amount of care at the call site reliably prevents.

So `RatingContext.forDirection` is the only constructor, it carries the
direction's substance and the confirmed brief and nothing about origin — not
the proposer, not the round, and not the angle, since an angle name is a hint
about the proposer's lens — and the text it produces is stored on the rating
record. The suite then checks the stored text rather than trusting the
constructor, because a session that arrived from anywhere else must be
*detectable* rather than merely unlikely.

Every rating turn also opens in a conversation of its own, for the same reason:
a shared chat would carry the prospector's case into the assessor's context
without any code passing it there.
