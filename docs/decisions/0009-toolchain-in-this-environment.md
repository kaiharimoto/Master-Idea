# 0009 · Building the pure packages before either client exists

**Made:** at the start of the build.
**Standing:** in force until the clients are started.

The brief's build order is: adopt the architecture, build the engine headless
and prove the three invariants from the command line, and only then put an
interface on top — because the invariants become unfixable once it sits there.

This session had a Dart SDK available and no Flutter, which happens to match
that order exactly. `mi_core` is analysed, formatted and tested here; the two
clients are not begun, and `docs/STATUS.md` says so rather than claiming a
parity that does not exist yet. Nothing about the clients has been stubbed or
mocked: the rule that neither platform is a port of the other applies from the
moment the first one starts, so neither has.
