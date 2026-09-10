# Fonts

**Source Serif 4** by Frank Grießhammer, Adobe. SIL Open Font License 1.1 —
the licence text is in `LICENSE-SourceSerif4-OFL.txt` and travels with the
binaries, which the OFL requires.

Committed rather than fetched at build time, for two reasons. A build that
downloads a font is a build that fails when a CDN does, and every screenshot in
`evidence/` has to be reproducible from a checkout months later. And the whole
treatment rests on the type: a fallback serif chosen by the operating system is
Noto Serif on Android and Georgia on Windows, so the same dossier would be set
two different ways and the result would read as assembled rather than designed.
