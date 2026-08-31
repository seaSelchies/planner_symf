# fodmap-streak-user-scoping

**Decided:** `PlannedTierProvider::plannedTiersByDate()`, `LoggedTierProvider::loggedTiersByDate()`,
and `GetFodmapStreakQuery` all gained a `string $userId` parameter/property (plain scalar, not a
Domain value object).

**From:** `docs/specs/use-fodmap-streak-schema.md`, Cases S12–S15, and
`docs/specs/use-fodmap-streak.md`'s Hidden dependencies section, which names this directly: every
table the hook reads (`meal_plans`, `recipe_ingredients`, `meal_logs`, `meal_log_ingredients`) is
restricted by Postgres row-level security to `auth.uid()`, invisibly — the original TypeScript
names no user anywhere because Postgres enforces it on every query automatically.

**Why:** invariant 9 — an outbound dependency is a Domain port, and what the port carries has to
be enough to satisfy the real contract, not just the contract visible at the call site. Doctrine
has no RLS equivalent: a `DoctrinePlannedTierProvider` written against a userless port signature
would return every user's data on every call, silently, with no test catching it (a fake
implementing the same signature just returns whatever it's given, same as the real bug). A plain
`string` was chosen over a dedicated `UserId` value object because no Auth module exists on `main`
yet (`AGENTS.md`: "No domain module has landed on `main` yet") — inventing one inside `Fodmap`
would misattribute a concept this module doesn't own, and risks colliding with whatever shape a
future Auth module gives its own user identifier. Widening this later, once Auth lands, is a
signature change that goes back through `/contract` like any other.

**What still has to be done:** `/build` has both Doctrine providers filter their queries by
`user_id = ?` (or the RLS-equivalent ownership join, for `recipe_ingredients`/
`meal_log_ingredients`) using the passed-in `$userId`.

**`ApiGetFodmapStreakController` has a real, unresolved gap this todo does not close.** Nothing in
this application yet resolves "the current authenticated user" — no session, no security context,
no Auth module. The controller's body cannot construct a real `GetFodmapStreakQuery($userId)`
until that exists. It stays a throwing stub until an authentication mechanism lands; this is not a
`/build` oversight to fix quietly, it's a genuine blocked dependency on work outside this module.

**What would settle it:** both Doctrine providers demonstrably scope their queries to the passed
`$userId` (an `Infrastructure` integration test against a real test Postgres, per
`.claude/rules/tests.md` rule 11, showing one user's fetch never returns another's rows), and
`ApiGetFodmapStreakController` has a real source for `$userId` to construct the query with.
