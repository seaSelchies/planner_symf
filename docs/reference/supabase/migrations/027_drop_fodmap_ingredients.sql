-- Migration 027: Удалить таблицу fodmap_ingredients
-- Все данные перенесены в ingredients (миграция 021).
-- Все FK и ссылки из кода убраны.

DROP TABLE IF EXISTS public.fodmap_ingredients;
