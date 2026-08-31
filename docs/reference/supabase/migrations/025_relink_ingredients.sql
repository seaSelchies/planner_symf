-- Migration 025: Перелинковать recipe_ingredients и meal_log_ingredients
-- Ищет совпадения по name_en И name_ru (после нормализации регистра)

-- ── recipe_ingredients ────────────────────────────────────────────────────

-- Совпадение по name_en
UPDATE recipe_ingredients ri
SET ingredient_id = i.id
FROM ingredients i
WHERE ri.ingredient_id IS NULL
  AND ri.ingredient_name IS NOT NULL
  AND i.name_en IS NOT NULL
  AND LOWER(TRIM(ri.ingredient_name)) = LOWER(TRIM(i.name_en));

-- Совпадение по name_ru
UPDATE recipe_ingredients ri
SET ingredient_id = i.id
FROM ingredients i
WHERE ri.ingredient_id IS NULL
  AND ri.ingredient_name IS NOT NULL
  AND i.name_ru IS NOT NULL
  AND LOWER(TRIM(ri.ingredient_name)) = LOWER(TRIM(i.name_ru));

-- ── meal_log_ingredients ──────────────────────────────────────────────────

-- Совпадение по name_en
UPDATE meal_log_ingredients mli
SET ingredient_id = i.id
FROM ingredients i
WHERE mli.ingredient_id IS NULL
  AND mli.ingredient_name IS NOT NULL
  AND i.name_en IS NOT NULL
  AND LOWER(TRIM(mli.ingredient_name)) = LOWER(TRIM(i.name_en));

-- Совпадение по name_ru
UPDATE meal_log_ingredients mli
SET ingredient_id = i.id
FROM ingredients i
WHERE mli.ingredient_id IS NULL
  AND mli.ingredient_name IS NOT NULL
  AND i.name_ru IS NOT NULL
  AND LOWER(TRIM(mli.ingredient_name)) = LOWER(TRIM(i.name_ru));

-- Проверка: сколько ещё без линка
SELECT
  'recipe_ingredients' AS tbl,
  COUNT(*) AS unlinked
FROM recipe_ingredients
WHERE ingredient_id IS NULL AND ingredient_name IS NOT NULL AND ingredient_name != ''
UNION ALL
SELECT
  'meal_log_ingredients',
  COUNT(*)
FROM meal_log_ingredients
WHERE ingredient_id IS NULL AND ingredient_name IS NOT NULL AND ingredient_name != '';
