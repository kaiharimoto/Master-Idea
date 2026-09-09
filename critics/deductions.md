# Per-finding deduction table

**Committed before the first review cycle. A value edited afterwards is a
failure condition.** A rubric total is tabulated from recorded findings using
these values, never asserted.

The category minimums sum to 92, so the effective bar is 92 with eight points
of slack — not 90.

| Category | Weight | Min | Finding | Deduction |
|---|---:|---:|---|---:|
| Coverage | 25 | 22 | A significant direction absent from the ledger entirely | 3 |
| | | | A territory dropped without a reason | 2 |
| | | | A gap named and never revisited or closed | 1 |
| Invariants | 20 | 20 | Any violation of any invariant | 20 |
| Direction quality | 15 | 13 | A direction committing a named anti-pattern | 2 |
| | | | A cluster not spanning conservative to reckless | 2 |
| | | | A session below its tier floor without being re-tiered | 4 |
| | | | Evidence of padding, splitting or duplication to reach a floor | 5 |
| Craft | 12 | 11 | An anti-goal present anywhere (chat, dashboard, blank canvas) | 4 |
| | | | The accent used on anything that is not a verdict or rating | 2 |
| | | | A region whose treatment differs from the rest | 2 |
| | | | Progress theatre in a run in progress | 3 |
| Range and parity | 10 | 9 | A region missing or unreachable on one client | 3 |
| | | | A domain profile that changes wording only | 3 |
| | | | A family member never executed in any stored session | 2 |
| Evidence | 8 | 8 | Any artifact missing, undersized, cropped or placeholder | 8 |
| | | | An artifact with no sidecar | 8 |
| Hand-off | 10 | 9 | A pitch carrying a direction the client did not select | 5 |
| | | | A provider-specific idiom in a pitch | 3 |
| | | | A pitch that reads as a session summary | 3 |
| | | | A cold-start reader who could not begin | 4 |

Invariants and Evidence are binary by construction: their single deduction
takes the category to zero, which is below its minimum, which fails the run.
