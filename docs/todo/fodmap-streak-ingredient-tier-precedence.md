# fodmap-streak-ingredient-tier-precedence

**Decided:** the catalogue-vs-recipe tier precedence rule (`ingredients.fodmap_tier` outranks
`recipe_ingredients.fodmap_tier`, with `Unknown` as the last resort) gets its own Domain class,
`IngredientTierPrecedence` (`src/Fodmap/Domain/MealPlan/IngredientTierPrecedence.php`), with
`resolve(?FodmapTier $catalogueTier, ?FodmapTier $recipeTier): FodmapTier`, rather than staying
implicit inside `DoctrinePlannedTierProvider`.

**From:** `docs/specs/use-fodmap-streak.md`, Cases C29–C32 (Step 2, ingredient tier resolution),
surfaced as a finding in `tests/Fodmap/CASE-COVERAGE.md`: "this precedence rule is real,
spec-mandated business logic ... but currently has no unit-testable home."

**Why:** invariant 21 — business-rule-checking lives in a dedicated Domain class, not buried
inside an Infrastructure adapter where no invariant protects it and no test can reach it without a
database. That the catalogue outranks the recipe row is a decision about the domain (a recipe
cannot quietly claim a different FODMAP tier than the shared catalogue); that two columns happen
to record it is a storage fact and stays the adapter's concern. `LoggedTierProvider`'s side has no
analogous two-column ambiguity anywhere in the spec, so only the planned-tier path needs this.

**What still has to be done:** `/build` implements `IngredientTierPrecedence::resolve()`, wires it
into `DoctrinePlannedTierProvider`'s constructor (that file already exists, so this step could
declare the new collaborator but not inject it), and has the provider convert each raw column with
`FodmapTier::tryFrom()` before calling `resolve()`. A `/cover` pass adds a Domain-level unit test
for `IngredientTierPrecedence` covering C29–C32 directly (no database needed), and
`tests/Fodmap/CASE-COVERAGE.md` is updated to point C29–C32 at that test instead of "not covered."

**What would settle it:** `IngredientTierPrecedence` has a passing unit test for C29–C32, and
`DoctrinePlannedTierProvider` calls it instead of embedding the `??`/`??` chain inline.
