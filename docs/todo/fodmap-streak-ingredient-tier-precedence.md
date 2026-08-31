# fodmap-streak-ingredient-tier-precedence

**Decided (revised):** the original two-source catalogue-vs-recipe precedence rule
(`IngredientTierPrecedence`, `src/Fodmap/Domain/MealPlan/IngredientTierPrecedence.php`) is retired.
It's replaced by a static factory on the enum itself: `FodmapTier::orUnknown(?FodmapTier
$catalogueTier): FodmapTier` (`src/Fodmap/Domain/Tier/FodmapTier.php`), called directly by both
`DoctrinePlannedTierProvider` and `DoctrineLoggedTierProvider` — no constructor-injected
collaborator, no separate class.

**From:** `docs/specs/use-fodmap-streak-schema.md`, Cases S17–S20, read at `/contract` alongside
`docs/specs/use-fodmap-streak.md`'s Discrepancies section on the same finding.

**Why:** the previous decision (see git history of this file) gave the precedence rule its own
class because two real columns existed to arbitrate between —
`recipe_ingredients.fodmap_tier` and the joined `ingredients.fodmap_tier`. Migration 026 drops
`recipe_ingredients.fodmap_tier` **and** `meal_log_ingredients.fodmap_tier`. Neither table has a
second source left; `ingredient_id → ingredients.fodmap_tier` is the only place a tier can come
from, on both the plan and the log side. What's left isn't a precedence decision between two
recorded values — it's "this ingredient's tier is on record, or it's `Unknown`," which is a fact
about `FodmapTier` itself, not a rule about how two storage columns relate. That's why it moved
onto the enum rather than staying a dedicated Domain class or being inlined twice.

**Behavior comparison, case by case (invariant 39).** Retiring the two-source rule is not a
no-op — it changes what gets resolved for two of the four cases the original rule was built to
satisfy. Comparing each of C29–C32 (`docs/specs/use-fodmap-streak.md`) against what
`FodmapTier::orUnknown()` actually returns given the equivalent live-schema input:

- **C29** — `ingredients.fodmap_tier = "low"` present → `catalogueTier = FodmapTier::Low`.
  `orUnknown(Low) = Low`. Original resolved `"low"`. **Unchanged.**
- **C30** — no joined catalogue row → `catalogueTier = null`. `orUnknown(null) = Unknown`.
  Original resolved `"moderate"`, via the now-dropped `recipe_ingredients.fodmap_tier` column
  fallback that no longer exists to fall back to. **Diverges, and crosses `isBad()`: `Moderate`
  (`isBad() = true`) → `Unknown` (`isBad() = false`).** A day whose only tier evidence takes this
  shape was counted **unsafe** by the original hook and is counted **safe** by this port — a real
  difference in the resulting streak count for that day, not merely a relabeling of an equivalent
  outcome. This divergence is forced, not chosen: the column the original fell back to is gone
  from the schema, so there is nothing left to recover `"moderate"` from.
- **C31** — neither source → `catalogueTier = null`. `orUnknown(null) = Unknown`. Original
  resolved `"unknown"`. **Unchanged.**
- **C32** — its premise (a linked catalogue row whose own `fodmap_tier` is `null`) is
  **unrealizable against the live schema**: `docs/specs/use-fodmap-streak-schema.md` S11 states
  `ingredients.fodmap_tier` is `NOT NULL DEFAULT 'unknown'`, so a linked row's tier is never SQL
  `NULL`. The nearest realizable analog — a linked row whose tier is the literal string
  `'unknown'` — gives `orUnknown(Unknown) = Unknown`, against the original's `"low"` (again via
  the dropped column). The resolved label differs, but `isBad(Low) = isBad(Unknown) = false` for
  both: **no boundary crossing, no effect on the streak count.**

Net: this port is deliberately not equivalent to the original at C30. `IngredientTierPrecedence`'s
retirement is correct given the schema — there is no design that preserves `"moderate"` here
without a column that no longer exists — but it is a genuine, structurally forced behavior change
that makes a previously-unsafe day safe, and it should be visible as exactly that, not folded
silently into "the class was redundant."

**What still has to be done:** `/build` implements `FodmapTier::orUnknown()` — **done**, see
`src/Fodmap/Domain/Tier/FodmapTier.php`. `DoctrinePlannedTierProvider::plannedTiersByDate()` and
`DoctrineLoggedTierProvider::loggedTiersByDate()` still need to each convert their
`ingredients.fodmap_tier` read with `FodmapTier::tryFrom()` and pass the result through
`orUnknown()` before building the per-date tier arrays — not done yet, no migration/test database
exists in this repo to write verified DBAL code against. A `/cover` pass should add a case
documenting the C30 divergence specifically (a day resolved only through a since-dropped
recipe-column fallback is now safe, not unsafe) alongside the existing `orUnknown()` coverage for
"a real tier" and "no linked ingredient."

**What would settle it:** `FodmapTier::orUnknown()` has a passing unit test — **done**
(`tests/Fodmap/Domain/Tier/FodmapTierTest::testOrUnknown`) — and both Doctrine providers call it
instead of embedding `?? FodmapTier::Unknown` inline or reintroducing a wrapper class. The C30
divergence above is additionally settled once a test exists asserting it explicitly, so a future
reader sees the behavior change was found and accepted, not missed.
