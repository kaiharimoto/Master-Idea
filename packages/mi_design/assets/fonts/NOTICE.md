# Fonts

**Inter** by Rasmus Andersson. SIL Open Font License 1.1 — the licence text is
in `LICENSE-Inter-OFL.txt` and travels with the binaries, which the OFL
requires.

The same four faces Master Prompt ships, deliberately. The two programs are one
family and are meant to be run side by side, so they are set in one typeface at
one scale; a different face would make them look like two unrelated tools that
happen to hand work to each other.

Committed rather than fetched at build time for two reasons: a build that
downloads a font is a build that fails when a CDN does, and a fallback face
chosen by the operating system is Roboto on Android and Segoe on Windows — the
same dossier set two different ways, which is the failure this vendoring
exists to prevent.

Medium (500) is the working weight and the reason Inter was chosen: it is the
neo-grotesque that actually ships a real 500.
