-- ============================================================
-- Migration 012: Canonicalise duplicate ingredient names
-- ============================================================

-- ── Болгарский перец ─────────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'болгарский перец'
WHERE ingredient_name IN (
  'болгарский перец (красный и жёлтый)',
  'болгарский перец (красный или жёлтый)',
  'красный болгарский перец'
);

UPDATE meal_log_ingredients
SET ingredient_name = 'болгарский перец'
WHERE ingredient_name IN (
  'болгарский перец (красный и жёлтый)',
  'болгарский перец (красный или жёлтый)',
  'красный болгарский перец'
);

-- ── Рыба ─────────────────────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'рыба'
WHERE ingredient_name IN (
  'рыба (горбуша или треска)',
  'филе горбуши или трески',
  'филе трески или горбуши'
);

UPDATE meal_log_ingredients
SET ingredient_name = 'рыба'
WHERE ingredient_name IN (
  'рыба (горбуша или треска)',
  'филе горбуши или трески',
  'филе трески или горбуши'
);

-- ── Зелёный лук ──────────────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'зелёный лук'
WHERE ingredient_name IN (
  'зелёный лук (перья)',
  'зелёный лук (только зелёная часть)'
);

UPDATE meal_log_ingredients
SET ingredient_name = 'зелёный лук'
WHERE ingredient_name IN (
  'зелёный лук (перья)',
  'зелёный лук (только зелёная часть)'
);

-- ── Помидор / помидоры ───────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'помидор'
WHERE ingredient_name = 'помидоры';

UPDATE meal_log_ingredients
SET ingredient_name = 'помидор'
WHERE ingredient_name = 'помидоры';

-- ── Огурец / огурцы ──────────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'огурец'
WHERE ingredient_name = 'огурцы';

UPDATE meal_log_ingredients
SET ingredient_name = 'огурец'
WHERE ingredient_name = 'огурцы';

-- ── Кабачок / кабачки ────────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'кабачок'
WHERE ingredient_name = 'кабачки';

UPDATE meal_log_ingredients
SET ingredient_name = 'кабачок'
WHERE ingredient_name = 'кабачки';

-- ── Оливки → маслины ─────────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'маслины'
WHERE ingredient_name IN ('оливки', 'чёрные оливки без косточки');

UPDATE meal_log_ingredients
SET ingredient_name = 'маслины'
WHERE ingredient_name IN ('оливки', 'чёрные оливки без косточки');

-- ── Безлактозное масло ───────────────────────────────────────
UPDATE recipe_ingredients
SET ingredient_name = 'безлактозное масло'
WHERE ingredient_name = 'безлактозное масло для жарки';

UPDATE meal_log_ingredients
SET ingredient_name = 'безлактозное масло'
WHERE ingredient_name = 'безлактозное масло для жарки';
