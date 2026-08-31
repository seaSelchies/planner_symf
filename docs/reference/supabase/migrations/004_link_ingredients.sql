-- ============================================================
-- Migration 004: Link recipe ingredients to FODMAP ingredients
-- ============================================================
-- Adds a nullable FK column on recipe_ingredients pointing at
-- fodmap_ingredients, then populates it for every ingredient
-- that can be matched to a FODMAP entry by Russian name.
--
-- Matching strategy:
--   • The FODMAP side is always an exact match on
--     translations->>'ru' so exactly one row is targeted.
--   • The recipe_ingredients side uses ILIKE patterns to
--     handle Russian case inflection (genitive, instrumental,
--     plural, etc.) and extra descriptors in the name.
--
-- Ingredients with no FODMAP table entry remain NULL:
--   вода, соль, перец, укроп, лавровый лист,
--   подсолнечное масло, безлактозное масло (all forms),
--   безлактозная сметана, безлактозный творог, рисовая бумага.
--
-- Idempotent: ADD COLUMN … IF NOT EXISTS is safe; every UPDATE
-- simply re-sets the same value on repeat runs.
-- ============================================================


-- ── Step 1: Add the nullable FK column ───────────────────────

ALTER TABLE recipe_ingredients
  ADD COLUMN IF NOT EXISTS fodmap_ingredient_id uuid
  REFERENCES fodmap_ingredients(id);


-- ── Step 2: Grains & Starches ────────────────────────────────

-- "рис" (plain) → рис (белый, длиннозёрный)
-- Use exact match to avoid hitting рисовая мука / рисовая бумага.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'рис (белый, длиннозёрный)'
  AND ri.ingredient_name = 'рис';

-- "рисовая мука" → рисовая мука
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'рисовая мука'
  AND ri.ingredient_name ILIKE '%рисовая мука%';

-- "гречка" (nom/gen: гречки) → гречка
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'гречка'
  AND ri.ingredient_name ILIKE '%гречк%';

-- "киноа" → киноа
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'киноа'
  AND ri.ingredient_name ILIKE '%киноа%';


-- ── Step 3: Dairy ─────────────────────────────────────────────

-- "безлактозное молоко" → молоко без лактозы
-- Matches "безлактозное молоко", "безлактозного молока", etc.
-- Does NOT match безлактозное масло (no "молок") or
-- безлактозная сметана (no "молок").
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'молоко без лактозы'
  AND ri.ingredient_name ILIKE '%лактозн%'
  AND ri.ingredient_name ILIKE '%молок%';

-- Note: безлактозное масло, безлактозная сметана, and
-- безлактозный творог have no direct FODMAP table entry
-- and are left NULL.


-- ── Step 4: Vegetables ───────────────────────────────────────

-- "морковь" (nom/gen: моркови / морковью) → морковь
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'морковь'
  AND ri.ingredient_name ILIKE '%морков%';

-- "картофель" (nom + gen: картофеля, картофелины) → картофель
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'картофель'
  AND ri.ingredient_name ILIKE '%картофел%';

-- "кабачок / кабачки" → кабачок (цукини)
-- Covers: кабачок, кабачки, кабачком, кабачка, кабачков
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'кабачок (цукини)'
  AND ri.ingredient_name ILIKE '%кабачк%';

-- "помидор / помидоры" → томат (обычный)
-- Covers: помидор, помидора, помидоры, помидоров
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'томат (обычный)'
  AND ri.ingredient_name ILIKE '%помидор%';

-- "огурец / огурцы" → огурец
-- Covers: огурец, огурцы, огурца, огурцов
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'огурец'
  AND (ri.ingredient_name ILIKE '%огурец%'
    OR ri.ingredient_name ILIKE '%огурц%');

-- "оливки / чёрные оливки без косточки" → оливки
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'оливки'
  AND ri.ingredient_name ILIKE '%оливк%';

-- "консервированная кукуруза" → кукуруза (консервированная)
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'кукуруза (консервированная)'
  AND ri.ingredient_name ILIKE '%кукуруз%';

-- "красный болгарский перец" / "болгарский перец (красный или жёлтый)"
-- / plain "болгарский перец" → болгарский перец (красный)
-- Yellow bell pepper has the same low FODMAP rating as red.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'болгарский перец (красный)'
  AND ri.ingredient_name ILIKE '%болгарский перец%';

-- "зелёный лук (только зелёная часть)" / "зелёный лук (перья)"
-- → лук зелёный (перо)
-- Only the green tops — this is exactly what these recipes use.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'лук зелёный (перо)'
  AND (ri.ingredient_name ILIKE '%зелёный лук%'
    OR ri.ingredient_name ILIKE '%лук%перья%'
    OR ri.ingredient_name ILIKE '%зелён%лук%');

-- "баклажан" → баклажан
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'баклажан'
  AND ri.ingredient_name ILIKE '%баклажан%';

-- "батат" → батат  (moderate FODMAP — up to ½ cup)
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'батат'
  AND ri.ingredient_name ILIKE '%батат%';

-- "замороженная стручковая фасоль" → стручковая фасоль
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'стручковая фасоль'
  AND ri.ingredient_name ILIKE '%стручков%'
  AND ri.ingredient_name ILIKE '%фасол%';


-- ── Step 5: Fruits ────────────────────────────────────────────

-- "консервированный ананас" → ананас
-- Canned pineapple is treated the same as fresh for FODMAP purposes.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'ананас'
  AND ri.ingredient_name ILIKE '%ананас%';

-- "сок лимона" → лимонный сок
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'лимонный сок'
  AND ri.ingredient_name ILIKE '%лимон%';


-- ── Step 6: Proteins ─────────────────────────────────────────

-- "яйца / яйцо" → яйцо
-- Covers: яйца, яйцо, яиц
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'яйцо'
  AND ri.ingredient_name ILIKE '%яйц%';

-- "куриное филе" / "куриный фарш" → куриная грудка
-- Both chicken breast fillet and minced chicken are breast meat.
-- "куриные бёдрышки или филе" is intentionally excluded here
-- (handled separately below).
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'куриная грудка'
  AND (ri.ingredient_name ILIKE '%куриное филе%'
    OR ri.ingredient_name ILIKE '%куриный фарш%');

-- "куриные бёдрышки или филе" → куриное бедро
-- Бёдрышки are thighs; the recipe uses mixed thigh/breast but
-- we key on the first-named cut.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'куриное бедро'
  AND ri.ingredient_name ILIKE '%бёдрышк%';

-- "филе индейки" → индейка
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'индейка'
  AND ri.ingredient_name ILIKE '%индейк%';

-- "тунец Calvo" / "тунец Calvo в воде" → тунец (консервированный в воде)
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'тунец (консервированный в воде)'
  AND ri.ingredient_name ILIKE '%тунец%';

-- Salmon / горбуша → лосось (свежий)
-- Горбуша (pink salmon) is a salmon species; all are low FODMAP.
-- Run BEFORE the треска update so that ambiguous "горбуша или
-- треска" names are subsequently resolved to треска below.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'лосось (свежий)'
  AND (ri.ingredient_name ILIKE '%лосос%'
    OR ri.ingredient_name ILIKE '%горбуш%');

-- Cod / треска → треска (белая рыба)
-- Runs AFTER the лосось update. For ambiguous ingredient names
-- such as "рыба (горбуша или треска)" and "филе горбуши или
-- трески" that contain both горбуша and треска, this update
-- wins and links them to треска. Both fish are low FODMAP, so
-- this is safe either way.
UPDATE recipe_ingredients ri
SET fodmap_ingredient_id = fi.id
FROM fodmap_ingredients fi
WHERE fi.translations->>'ru' = 'треска (белая рыба)'
  AND ri.ingredient_name ILIKE '%треск%';


-- ── Ingredients intentionally left NULL ──────────────────────
-- The following appear in recipe_ingredients but have no
-- suitable FODMAP table entry:
--
--   вода                      – water; not a FODMAP concern
--   соль                      – plain salt; universally safe
--   перец                     – black pepper seasoning; universally safe
--   укроп                     – dill; universally safe
--   лавровый лист             – bay leaf; universally safe
--   подсолнечное масло        – sunflower oil; universally safe
--   безлактозное масло        – lactose-free butter; no dedicated entry
--   безлактозное масло для жарки – same
--   безлактозная сметана      – lactose-free sour cream; no entry
--   безлактозный творог 5%    – lactose-free quark; no entry
--   рисовая бумага            – rice paper wrappers; no entry
