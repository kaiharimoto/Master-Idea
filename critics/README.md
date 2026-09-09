# The judgeset

The ten critic prompts, the closed ordinal rating vocabularies and the
per-finding deduction table. **Committed before the first review cycle and
unchanged afterwards.** A diff in this directory after cycle one is a failure
condition, not an improvement: a rubric whose deductions move between cycles
cannot show progress, only motion.

Each critic runs as a fresh-context subagent. It receives the mission goal, the
captured evidence and the rubric — never the build history, and never the
builder's account of what was done. The one exception is the decision log
auditor, which exists precisely to read the reasoning.
