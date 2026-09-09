# Ordinal rating vocabularies

Closed, ordered, worst first. **Committed before the first review cycle and
never reworded.** Every rating record names the vocabulary it drew from, so a
verdict read in isolation still means something.

Ratings are words and never numerals. A number invites averaging, and averaging
is how dissent disappears. The ordering below exists so a dossier can be
sorted; it never reaches the page.

Each vocabulary names the highest rung that still counts as a **rejection**. A
vocabulary with no rejecting rung cannot reject anything, which is the
diplomatic-rating failure written down as a data structure.

| Vocabulary | Rungs, worst first | Rejects at or below |
|---|---|---|
| `strength` | unfounded, weak, sound, strong, commanding | weak |
| `presence` | absent, gestured, specified, demonstrated | gestured |
| `distance` | restatement, variant, departure, break | restatement |
| `plausibility` | unattemptable, doubtful, attemptable, straightforward | unattemptable |
| `consequence` | inert, marginal, material, decisive | inert |
| `fit` | contradicts, strains, consistent, fulfils | contradicts |

| Dimension | Vocabulary | Catches |
|---|---|---|
| Distinctness | `distance` | Restatement disguised as a direction |
| Mechanism | `presence` | Consultant ambition with nothing underneath |
| Ambition | `strength` | Safe incrementalism |
| Feasibility | `plausibility` | A reckless option with no attemptable form |
| Consequence | `consequence` | The novel, workable direction that changes nothing |
| Fidelity | `fit` | A direction that overturns the client's constitution |

`packages/mi_core/test/families_test.dart` asserts this file and the catalog in
`dimensions.dart` agree, so a change to one that is not a change to the other
fails the suite.
