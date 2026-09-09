# 0005 · Sharing an interview answer requires a gap of one's own

**Made:** while writing the traceability check, and revised the same day after
the first honest run failed it.
**Standing:** in force.

The brief's failure condition reads: more than one direction tracing to the
same interview answer without also naming a distinct ledger gap. The strict
reading — each sharer must name a gap, and the gaps must differ from each
other — is the one implemented.

It has a consequence worth recording, because it looked like a bug first. The
first end-to-end run failed traceability with every direction sourced to
`raw-idea`. That was the check working. But the run then failed again with
directions pairing the same answer to the same single gap, because the
cartographer named one gap per barrier. **A map that names one gap a round
cannot distinguish two directions that answer the same client sentence.** The
fix is in the map, not the rule: the cartographer names several gaps per
barrier, and a run whose map is coarse will fail its own invariant rather than
quietly producing directions nobody can tell apart.

Round one is the exception that proves it: with no map yet, a first-round
direction can only be distinguished by which answer it came from, so first-round
breadth is bounded by the number of interview answers. That is a real
constraint on the tool and it is the right one.
