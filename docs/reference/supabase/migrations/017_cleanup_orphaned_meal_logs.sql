-- 017_cleanup_orphaned_meal_logs.sql
--
-- Clean up meal_log_ingredients (and empty meal_logs) that have no
-- corresponding meal_plans row — left over from before the fix that
-- clears logs when a meal plan slot is cleared in the planner.
--
-- meal_plans.week_start (date) + meal_plans.day_of_week (int, 0=Mon)
-- gives the actual date of the slot.

-- Step 1: remove ingredients from logs whose plan slot no longer exists
DELETE FROM meal_log_ingredients
WHERE meal_log_id IN (
  SELECT ml.id
  FROM meal_logs ml
  WHERE NOT EXISTS (
    SELECT 1
    FROM meal_plans mp
    WHERE mp.user_id    = ml.user_id
      AND mp.meal_type  = ml.meal_type
      AND (mp.week_start::date + mp.day_of_week) = ml.date::date
  )
);

-- Step 2: remove now-empty logs that also have no custom notes
DELETE FROM meal_logs
WHERE (notes IS NULL OR trim(notes) = '')
  AND NOT EXISTS (
    SELECT 1 FROM meal_log_ingredients mli
    WHERE mli.meal_log_id = meal_logs.id
  )
  AND NOT EXISTS (
    SELECT 1
    FROM meal_plans mp
    WHERE mp.user_id    = meal_logs.user_id
      AND mp.meal_type  = meal_logs.meal_type
      AND (mp.week_start::date + mp.day_of_week) = meal_logs.date::date
  );
