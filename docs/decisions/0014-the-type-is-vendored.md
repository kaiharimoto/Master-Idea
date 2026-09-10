# 0014 · The typeface is committed, not fetched

**Made:** while building the design system.
**Standing:** in force.

Source Serif 4 is committed to `packages/mi_design/assets/fonts` under the OFL,
with the licence text beside it as the licence requires.

Two reasons, and the second is the one that matters. A build that downloads a
font is a build that fails when a CDN does — and every screenshot in
`evidence/` has to be reproducible from a checkout months from now. And the
whole treatment rests on the type: a fallback serif chosen by the operating
system is Noto Serif on Android and Georgia on Windows, so the same dossier
would be set two different ways and the result would read as assembled rather
than designed, which is precisely what the craft standard forbids.

The theme uses the package-qualified family name — `packages/mi_design/…` —
because that is what a font declared by a package is actually registered as.
The unqualified name resolves to nothing and falls through to the platform
serif *silently*, which is the failure above arriving without a single error
message. `treatment_test.dart` asserts the qualified form.
