# 0006 · The invariant suite lives in `mi_core`, not in a root `test/invariants/`

**Made:** while laying out the repository.
**Standing:** in force. **Deviation from the brief's file structure** — recorded
here and in `parity.md`.

The brief's file structure names `test/invariants/`. A root-level test
directory in a Dart repository needs its own `pubspec.yaml` and its own
resolution step, which is a third CI job whose only purpose is directory
naming.

More importantly the suite is not only a test. It is a thing the app runs on
demand against any stored session — `InvariantSuite.run(session)` — so that
traceability, independent rating and run-until-dry are checkable next month
rather than only on the day. Logic the app calls belongs in the pure package.

So: `packages/mi_core/lib/src/invariants/invariant_suite.dart` is the suite,
and `packages/mi_core/test/invariants_test.dart` holds the negative tests that
prove it has teeth — one per invariant, each breaking exactly one thing in a
session that was otherwise sound. Where the brief and Master Prompt's
architecture disagree, the repository wins; this is that rule applied.
