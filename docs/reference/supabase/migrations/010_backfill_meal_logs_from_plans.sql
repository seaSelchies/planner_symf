-- Migration 010: Backfill meal_log entries for existing meal_plans
-- Run manually in Supabase SQL editor.
--
-- For every meal_plan row that has a recipe assigned and no matching
-- meal_log yet, this script:
--   1. Creates the meal_log record
--   2. Copies recipe_ingredients (with FODMAP tiers) as meal_log_ingredients

-- Step 1: Create missing meal_log rows
INSERT INTO meal_logs (user_id, date, meal_type, notes)
SELECT
  mp.user_id,
  (mp.week_start::date + (mp.day_of_week * INTERVAL '1 day'))::date AS date,
  mp.meal_type,
  NULL AS notes
FROM meal_plans mp
WHERE mp.recipe_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1
    FROM meal_logs ml
    WHERE ml.user_id  = mp.user_id
      AND ml.date     = (mp.week_start::date + (mp.day_of_week * INTERVAL '1 day'))::date
      AND ml.meal_type = mp.meal_type
  );

-- Step 2: Insert ingredients for the logs that were just created
-- (identified by having no meal_log_ingredients yet)
INSERT INTO meal_log_ingredients (meal_log_id, ingredient_name, fodmap_tier)
SELECT
  ml.id                                              AS meal_log_id,
  ri.ingredient_name,
  COALESCE(fi.tier, ri.fodmap_tier)                  AS fodmap_tier
FROM meal_logs ml
JOIN meal_plans mp
  ON  mp.user_id   = ml.user_id
  AND mp.meal_type = ml.meal_type
  AND (mp.week_start::date + (mp.day_of_week * INTERVAL '1 day'))::date = ml.date
  AND mp.recipe_id IS NOT NULL
JOIN recipe_ingredients ri
  ON  ri.recipe_id = mp.recipe_id
LEFT JOIN fodmap_ingredients fi
  ON  fi.id = ri.fodmap_ingredient_id
WHERE NOT EXISTS (
  SELECT 1
  FROM meal_log_ingredients mli
  WHERE mli.meal_log_id = ml.id
);
