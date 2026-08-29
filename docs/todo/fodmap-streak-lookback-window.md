# fodmap-streak-lookback-window

**Decided:** the plan-side window (last 16 Mondays) and the log-side window (last 112 continuous
days) will share one definition instead of being computed independently, so the two sources
cannot silently disagree on how far back they look.

**From:** `docs/specs/use-fodmap-streak.md`, Open question "Is the ~16-week lookback window a
deliberate performance/cost bound, or an accidental cap...", and the Edge case "Implicit lookback
window" noting the two windows "are computed differently... and neither window size is documented
or configurable."

**Why:** nothing in `AGENTS.md` forces this change — the original's inconsistency between a
discrete 16-Monday list and a continuous 112-day range isn't an invariant violation, just a latent
bug. Per invariant 39, an undirected behavior improvement during a port needs a human ruling
before it's made; the human chose to unify rather than reproduce the original's exact (possibly
buggy) shape.

**What still has to be done:** `/build` introduces one shared window definition (e.g. a small
Domain value or constant consumed by both `DoctrinePlannedTierProvider` and
`DoctrineLoggedTierProvider`) so both providers derive their date range from the same `$today` and
the same length. The concrete window length (still nominally "16 weeks") and whether it becomes a
configurable value are not decided by this todo — that was Open question territory this ticket
does not close; whoever picks it up should either default to the literal 16/112 or raise the
configurability question with a human.

**What would settle it:** both providers derive their range from the same shared definition (code
inspection), and `/cover` has a test showing a date is included in one map if and only if it's
also reachable by the other's window computation, for a given fixed clock.
