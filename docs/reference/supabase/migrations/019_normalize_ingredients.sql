-- Migration 019: Нормализация незалинкованных ингредиентов
-- Линкует recipe_ingredients к fodmap_ingredients где матч однозначен.
-- Идемпотентна: UPDATE повторно проставит те же значения.

-- ── 1. укроп → dill (low) ────────────────────────────────────────────────
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'укроп'
  AND ri.ingredient_name = 'укроп'
  AND ri.fodmap_ingredient_id IS NULL;

-- ── 2. кабачок → кабачок (low) ───────────────────────────────────────────
-- Берём запись 'кабачок' (без скобок), чтобы не путать с 'кабачок (цукини)'
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'кабачок'
  AND ri.ingredient_name = 'кабачок'
  AND ri.fodmap_ingredient_id IS NULL;

-- ── 3. лавровый лист → bay leaf (low) ────────────────────────────────────
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'лавровый лист'
  AND ri.ingredient_name = 'лавровый лист'
  AND ri.fodmap_ingredient_id IS NULL;

-- ── 4. корица → cinnamon (low) ───────────────────────────────────────────
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'корица'
  AND ri.ingredient_name = 'корица'
  AND ri.fodmap_ingredient_id IS NULL;

-- ── 5. подсолнечное масло → растительное масло (low) ─────────────────────
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'растительное масло'
  AND ri.ingredient_name = 'подсолнечное масло'
  AND ri.fodmap_ingredient_id IS NULL;

-- ── 6. безлактозное масло → сливочное масло (low) ────────────────────────
-- Безлактозное масло = обычное сливочное масло, лактоза в масле и так
-- минимальна. FODMAP-профиль идентичен.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'сливочное масло'
  AND ri.ingredient_name = 'безлактозное масло'
  AND ri.fodmap_ingredient_id IS NULL;

-- ── НЕ линкуем ────────────────────────────────────────────────────────────
-- соль            — нет в fodmap_ingredients (FODMAP не актуален)
-- вода            — нет в fodmap_ingredients
-- перец           — в рецептах означает чёрный молотый перец, не болгарский;
--                   совпадение с 'болгарский перец (красный)' было бы ошибкой
-- разрыхлитель    — нет в fodmap_ingredients (как правило low, но не в базе)
-- безлактозный творог / 5% — безлактозный творог LOW FODMAP, тогда как
--                   'зернёный творог' в базе HIGH. Разные продукты — не линкуем.
-- безлактозная сметана — нет подходящей записи в fodmap_ingredients
-- рисовая бумага  — не то же самое, что 'рисовая мука'
