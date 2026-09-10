# 0012 · Two first-class clients, from one Flutter application

**Made:** when the clients were started.
**Standing:** in force.

The brief requires Android and Windows at true feature parity, neither a port
of the other, and makes "one platform stubbed while the other is built" a
failure condition. The cheapest way to *fail* that is to write two clients.

So there is one Flutter application with two platform folders, exactly as
Master Prompt does it. Every region is one widget tree; both platforms run it;
parity is a property of there being one of them rather than a promise somebody
has to keep. The renderers make it stronger still: the dossier, the ledger and
the pitch all arrive as an `MiDocument` from `mi_core` and are laid out by one
`DocumentView`, so neither platform can decide for itself what a verdict looks
like.

**What genuinely differs is the transport, and only the transport.** A desktop
drives the Claude CLI as a subprocess and a sitting there is unattended. A
phone has no CLI, so every turn is carried by hand — `HandoverCouncil`
implements the same `CouncilTransport` the CLI one does, and the same
`CouncilRun` drives it, which means a sitting conducted by hand produces the
same records, the same invariants and the same dossier.

**The Android client is never presented as running unattended.** It says so on
the sitting screen in as many words. A six-hour sitting on that transport is
six hours of a person copying, and claiming the desktop's autonomy for it would
be the one platform difference that matters being papered over.
