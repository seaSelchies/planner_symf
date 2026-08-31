-- 1. Новая таблица ingredients
CREATE TABLE public.ingredients (
  id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name_en     text NOT NULL,
  name_ru     text,
  fodmap_tier text CHECK (fodmap_tier IN ('low','moderate','high','unknown')) NOT NULL DEFAULT 'unknown',
  notes_en    text,
  notes_ru    text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;

-- Читать могут все аутентифицированные
CREATE POLICY "read all" ON public.ingredients FOR SELECT TO authenticated USING (true);
-- Писать могут все аутентифицированные
CREATE POLICY "write all" ON public.ingredients FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. Перенести fodmap_ingredients → ingredients
INSERT INTO public.ingredients (id, name_en, name_ru, fodmap_tier, notes_en, notes_ru)
SELECT
  id,
  translations->>'en',
  translations->>'ru',
  tier,
  notes->>'en',
  notes->>'ru'
FROM public.fodmap_ingredients;

-- 3. Добавить ingredient_id FK в recipe_ingredients
ALTER TABLE public.recipe_ingredients
  ADD COLUMN IF NOT EXISTS ingredient_id uuid REFERENCES public.ingredients(id) ON DELETE SET NULL;

-- Заполнить из fodmap_ingredient_id (уже совпадают по ID)
UPDATE public.recipe_ingredients
SET ingredient_id = fodmap_ingredient_id
WHERE fodmap_ingredient_id IS NOT NULL;

-- Для незалинкованных — создать новые записи в ingredients и сослаться
INSERT INTO public.ingredients (name_en, fodmap_tier)
SELECT DISTINCT ingredient_name, 'unknown'
FROM public.recipe_ingredients
WHERE ingredient_id IS NULL AND ingredient_name IS NOT NULL AND ingredient_name != '';

UPDATE public.recipe_ingredients ri
SET ingredient_id = i.id
FROM public.ingredients i
WHERE ri.ingredient_id IS NULL
  AND LOWER(TRIM(ri.ingredient_name)) = LOWER(TRIM(i.name_en));

-- 4. Добавить ingredient_id FK в meal_log_ingredients
ALTER TABLE public.meal_log_ingredients
  ADD COLUMN IF NOT EXISTS ingredient_id uuid REFERENCES public.ingredients(id) ON DELETE SET NULL;

-- Залинковать по имени
UPDATE public.meal_log_ingredients mli
SET ingredient_id = i.id
FROM public.ingredients i
WHERE mli.ingredient_id IS NULL
  AND LOWER(TRIM(mli.ingredient_name)) = LOWER(TRIM(i.name_en));

-- Для незалинкованных логов — создать новые записи
INSERT INTO public.ingredients (name_en, fodmap_tier)
SELECT DISTINCT ingredient_name, 'unknown'
FROM public.meal_log_ingredients
WHERE ingredient_id IS NULL AND ingredient_name IS NOT NULL AND ingredient_name != ''
ON CONFLICT DO NOTHING;

UPDATE public.meal_log_ingredients mli
SET ingredient_id = i.id
FROM public.ingredients i
WHERE mli.ingredient_id IS NULL
  AND LOWER(TRIM(mli.ingredient_name)) = LOWER(TRIM(i.name_en));
