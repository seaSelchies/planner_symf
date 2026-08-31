-- Migration 022: Fix custom ingredients where Russian text landed in name_en
-- When custom ingredient names (Russian) were inserted into ingredients table,
-- they were placed in name_en. Move them to name_ru and clear name_en.

-- Step 1: для строк где name_en содержит кириллицу — скопировать в name_ru
UPDATE public.ingredients
SET name_ru = name_en
WHERE name_en ~ '[А-яЁёҐґЄєІіЇї]'
  AND name_ru IS NULL;

-- Step 2: очистить name_en для таких строк (оставить NULL — приложение покажет name_ru как fallback)
-- Но name_en NOT NULL, поэтому временно ставим пустую строку — надо сделать nullable
ALTER TABLE public.ingredients ALTER COLUMN name_en DROP NOT NULL;

UPDATE public.ingredients
SET name_en = NULL
WHERE name_en ~ '[А-яЁёҐґЄєІіЇї]'
  AND name_ru IS NOT NULL;
