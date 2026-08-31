-- ============================================================
-- Migration 011: Merge tuna variants into one canonical name
-- ============================================================
-- Renames "тунец Calvo" and "тунец Calvo в воде" to
-- "тунец консервированный" in recipe_ingredients,
-- meal_log_ingredients, and fodmap_ingredients translations.
-- ============================================================

-- 1. recipe_ingredients
UPDATE recipe_ingredients
SET ingredient_name = 'тунец консервированный'
WHERE ingredient_name ILIKE '%тунец%calvo%'
   OR ingredient_name ILIKE '%calvo%тунец%';

-- 2. meal_log_ingredients (user-entered logs)
UPDATE meal_log_ingredients
SET ingredient_name = 'тунец консервированный'
WHERE ingredient_name ILIKE '%тунец%calvo%'
   OR ingredient_name ILIKE '%calvo%тунец%';

-- 3. Update the canonical name in fodmap_ingredients translations
UPDATE fodmap_ingredients
SET translations = jsonb_set(
    translations,
    '{ru}',
    '"тунец консервированный"'
)
WHERE translations->>'ru' = 'тунец (консервированный в воде)';
