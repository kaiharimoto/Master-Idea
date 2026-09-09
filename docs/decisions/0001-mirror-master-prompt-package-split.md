# 0001 · Mirror Master Prompt's package split, not its package count

**Made:** at the start of the build, before any code.
**Standing:** in force.

The brief makes Master Prompt's architecture a hard constraint and says the
repository wins where the two disagree. Master Prompt is `mp_core` (pure Dart),
`mp_runner` (dart:io), `mp_design` (Flutter) and `app/`, with path dependencies
and **no pub workspace** — its own working document records that a workspace
including the Flutter packages made `dart pub get` need the Flutter SDK, which
broke CI and destroyed the property the pure packages exist to have.

Master Idea adopts the same split and the same refusal: `mi_core` pure,
`mi_engine` dart:io, and `mi_design` + `app/` to follow. The names differ
because two packages called `mp_core` on one machine would be ambiguous in
every import.

The one deliberate difference in *count*: Master Prompt's runner supervises a
single long CLI conversation, where this one drives many concurrent seats. That
is a difference in what the package does, not in where the line is drawn, so
`mi_engine` sits exactly where `mp_runner` sits.
