-- Migration 026: Удалить устаревшие текстовые колонки
-- Все строки имеют ingredient_id — текстовые поля больше не нужны.

-- meal_log_ingredients
ALTER TABLE public.meal_log_ingredients DROP COLUMN IF EXISTS ingredient_name;
ALTER TABLE public.meal_log_ingredients DROP COLUMN IF EXISTS fodmap_tier;

-- recipe_ingredients
ALTER TABLE public.recipe_ingredients DROP COLUMN IF EXISTS ingredient_name;
ALTER TABLE public.recipe_ingredients DROP COLUMN IF EXISTS fodmap_ingredient_id;
ALTER TABLE public.recipe_ingredients DROP COLUMN IF EXISTS fodmap_tier;
