# 0020 · The screens are rendered, not compared — and the native channel is a save

**Made:** while walking the whole workflow before shipping. Two calls that had
been made in code and never written down.

## The shots

`shots_test.dart` renders the real regions to `app/test/shots/` and asserts
almost nothing. It is skipped in an ordinary run because font rasterisation
differs between machines, and a pixel comparison on a runner goes red for
reasons that have nothing to do with the design.

The trade is deliberate and worth naming: **a visual regression cannot fail
this build.** What justifies it is that the shots found two defects the first
time they were looked at — a section header printing `null /`, and a dissent
label printing its own interpolation — and neither would ever have failed an
assertion, because both were widgets rendering exactly what they were told to.
Looking is the check; the pixels are not.

CI now renders them on every push and uploads them, which catches the one
thing a skipped test cannot: a region that *throws* while rendering. That is a
real failure the suite would otherwise miss entirely, since the shots are the
only tests that build some of these screens at all.

One thing worth knowing, because it cost a session: a `skip` on a tag wins
over `--tags`, so the command this repository documented for regenerating them
rendered nothing and reported "All tests skipped", which reads exactly like
success. It needs `--run-skipped`.

## The native channel

`MainActivity` answers three methods: `install`, `share` and `save`. The
second and third existed for a build and a half without Dart ever calling
them, so the dossier and the ledger could not leave the app at all and the
pitch could only be copied. They are called now.

**`save` is the default and `share` is the second offer**, which is the way
round it looks wrong. A share always opens a *new* conversation — the
receiving app decides that, and `ACTION_SEND` carries no way to say otherwise
— and a pitch usually belongs in one that already exists. A saved file can be
attached to anything.

Files are staged in the one cache directory `file_paths.xml` exposes, and
nowhere else. A provider over internal storage would hand every stored
session, which is to say every interview answer the client ever gave, to any
app holding the URI.
