# fodmap-entity-ownership

**Decided:** Ingredient, Recipe, RecipeIngredient, MealPlan, MealLog, and MealLogIngredient are
not owned by the Fodmap module. All six map tables Fodmap only reads through joins
(`meal_plans`/`recipe_ingredients`/`ingredients` for the plan-side fallback, `meal_logs`/
`meal_log_ingredients`/`ingredients` for the log side) and writes none of them. They live at
`src/Fodmap/Domain/Shared/`.

**From:** `docs/specs/use-fodmap-streak-schema.md` (table list in Contract) and
`docs/specs/use-fodmap-streak.md` (Hidden dependencies — read-only Supabase queries), read
together at `/entity`.

**Why:** the ownership test is whether the module *writes* the table and names the concept in
its own language, not whether it needs to read it. Fodmap has no command handler touching any
of these six tables; "recipe," "meal plan," "meal log," and "ingredient" are concepts a future
recipe-management / meal-planning / ingredient-catalogue module will own outright.

**What still has to be done:** when the module that owns each concept lands, Fodmap's
Infrastructure stops mapping that table itself and reads it through that module's own ports
instead; the entity moves out of `Domain/Shared/` into that module's `Domain/`.

**What would settle it:** the owning module exists on `main` and Fodmap's Infrastructure calls
its ports rather than mapping the table directly.
