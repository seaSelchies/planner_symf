-- ============================================================
-- Migration 005: Sync fodmap_tier from linked fodmap_ingredients
-- ============================================================
-- Migration 004 populated fodmap_ingredient_id for every
-- recipe_ingredient it could match, but left fodmap_tier
-- unchanged (still 'unknown' for all seeded rows).
--
-- This migration copies tier from the authoritative
-- fodmap_ingredients table into recipe_ingredients.fodmap_tier
-- for every row that has a valid link.
--
-- Idempotent: the WHERE clause skips rows already in sync.
-- Rows where fodmap_ingredient_id IS NULL are untouched.
-- ============================================================

UPDATE recipe_ingredients ri
SET    fodmap_tier = fi.tier
FROM   fodmap_ingredients fi
WHERE  ri.fodmap_ingredient_id = fi.id
  AND  ri.fodmap_tier IS DISTINCT FROM fi.tier;
