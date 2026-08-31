-- ============================================================
-- Migration 028: Week 4 — Summer menu
-- Adds recipes 32–37 + meal_plans for 2026-06-08
--
-- После migration 026 колонка ingredient_name удалена из recipe_ingredients.
-- Используем ingredient_id (FK → ingredients).
-- Временная функция _tmp_find_or_create_ingredient создаётся и удаляется
-- в рамках этой миграции.
-- ============================================================

-- ── Временная вспомогательная функция ──────────────────────────────────────
CREATE OR REPLACE FUNCTION _tmp_find_or_create_ingredient(
  p_name_ru text,
  p_name_en text DEFAULT NULL,
  p_tier    text DEFAULT 'unknown'
)
RETURNS uuid AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id
  FROM ingredients
  WHERE LOWER(name_ru) = LOWER(p_name_ru)
  LIMIT 1;

  IF v_id IS NULL THEN
    INSERT INTO ingredients (name_en, name_ru, fodmap_tier)
    VALUES (COALESCE(p_name_en, p_name_ru), p_name_ru, p_tier)
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$ LANGUAGE plpgsql;


-- ── Основной блок ──────────────────────────────────────────────────────────
DO $$
DECLARE
  v_user_id uuid;
  v_rid     uuid;
  v_iid     uuid;   -- переиспользуемая переменная для ingredient_id

  -- Новые рецепты
  r32  uuid;   -- Рисовая каша с малиной
  r33  uuid;   -- Летний салат с курицей, помидором и огурцом
  r34  uuid;   -- Куриный суп со свежей кукурузой
  r35  uuid;   -- Гречка с лососем
  r36  uuid;   -- Судак, запечённый с картофелем
  r37  uuid;   -- Курица, тушёная с молодыми кабачками

  -- Существующие рецепты
  r_omlet    uuid;
  r_rolls    uuid;
  r_blini    uuid;
  r_eggs_tom uuid;
  r_pot_tuna uuid;
  r_quinoa   uuid;
  r_tuna_sal uuid;
  r_eggs_pep uuid;
  r_buck_zuc uuid;
  r_fish_pot uuid;

  v_week date := '2026-06-22';

BEGIN

  -- ── 0. Resolve user ──────────────────────────────────────────────────────
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'selchies.sea@gmail.com'
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User selchies.sea@gmail.com not found in auth.users';
  END IF;


  -- ══════════════════════════════════════════════════════════════════════════
  -- ЧАСТЬ 1: НОВЫЕ РЕЦЕПТЫ
  -- ══════════════════════════════════════════════════════════════════════════

  -- ── 32. Рисовая каша с малиной ──────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Рисовая каша с малиной') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Рисовая каша с малиной',
            'Рис промыть до прозрачной воды. Залить смесью молока и воды, варить 15–20 минут на небольшом огне, помешивая. Посолить, добавить масло и сахар. Снять с огня, дать настояться 5 минут под крышкой. Подавать с малиной.',
            2)
    RETURNING id INTO v_rid;

    v_iid := _tmp_find_or_create_ingredient('рис', 'rice', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 100, 'г');

    v_iid := _tmp_find_or_create_ingredient('безлактозное молоко', 'lactose-free milk', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 200, 'мл');

    v_iid := _tmp_find_or_create_ingredient('вода', 'water', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 150, 'мл');

    v_iid := _tmp_find_or_create_ingredient('безлактозное масло', 'lactose-free butter', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 10, 'г');

    v_iid := _tmp_find_or_create_ingredient('сахар', 'sugar', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'ч.л.');

    v_iid := _tmp_find_or_create_ingredient('соль', 'salt', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'щепотка');

    v_iid := _tmp_find_or_create_ingredient('малина', 'raspberry', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 120, 'г');
  END IF;
  SELECT id INTO r32 FROM recipes WHERE user_id = v_user_id AND name = 'Рисовая каша с малиной';


  -- ── 33. Летний салат с курицей, помидором и огурцом ─────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Летний салат с курицей, помидором и огурцом') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Летний салат с курицей, помидором и огурцом',
            'Куриное филе отварить в подсолённой воде 20 минут, остудить и нарезать полосками. Помидор и огурец нарезать кубиками. Смешать всё в миске, посолить, заправить оливковым маслом. При желании добавить укроп.',
            2)
    RETURNING id INTO v_rid;

    v_iid := _tmp_find_or_create_ingredient('куриное филе', 'chicken fillet', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 250, 'г');

    v_iid := _tmp_find_or_create_ingredient('помидор', 'tomato', 'moderate');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 2, 'шт');

    v_iid := _tmp_find_or_create_ingredient('огурец', 'cucumber', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'шт');

    v_iid := _tmp_find_or_create_ingredient('оливковое масло', 'olive oil', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 2, 'ст.л.');

    v_iid := _tmp_find_or_create_ingredient('соль', 'salt', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');

    v_iid := _tmp_find_or_create_ingredient('укроп', 'dill', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');
  END IF;
  SELECT id INTO r33 FROM recipes WHERE user_id = v_user_id AND name = 'Летний салат с курицей, помидором и огурцом';


  -- ── 34. Куриный суп со свежей кукурузой ─────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Куриный суп со свежей кукурузой') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Куриный суп со свежей кукурузой',
            'Куриную грудку сварить в 1,5 л воды, вынуть и нарезать. Бульон процедить. Добавить морковь кубиками, картофель кубиками, варить 10 минут. Добавить кукурузные зёрна, срезанные с початка, и курицу. Варить ещё 15 минут. Посолить, посыпать укропом.',
            4)
    RETURNING id INTO v_rid;

    v_iid := _tmp_find_or_create_ingredient('куриная грудка', 'chicken breast', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 400, 'г');

    v_iid := _tmp_find_or_create_ingredient('кукуруза (початок)', 'corn (cob)', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'шт');

    v_iid := _tmp_find_or_create_ingredient('картофель', 'potato', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 300, 'г');

    v_iid := _tmp_find_or_create_ingredient('морковь', 'carrot', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'шт');

    v_iid := _tmp_find_or_create_ingredient('вода', 'water', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1500, 'мл');

    v_iid := _tmp_find_or_create_ingredient('соль', 'salt', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');

    v_iid := _tmp_find_or_create_ingredient('укроп', 'dill', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');
  END IF;
  SELECT id INTO r34 FROM recipes WHERE user_id = v_user_id AND name = 'Куриный суп со свежей кукурузой';


  -- ── 35. Гречка с лососем ────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с лососем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Гречка с лососем',
            'Гречку промыть, залить водой 1:2, варить 15–18 минут до готовности. Лосось посолить, сбрызнуть лимонным соком, выложить в форму. Запекать при 180°C 15–18 минут. Подавать гречку с кусочком лосося, полить оливковым маслом и посыпать укропом.',
            2)
    RETURNING id INTO v_rid;

    v_iid := _tmp_find_or_create_ingredient('гречка', 'buckwheat', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 150, 'г');

    v_iid := _tmp_find_or_create_ingredient('лосось', 'salmon', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 250, 'г');

    v_iid := _tmp_find_or_create_ingredient('лимонный сок', 'lemon juice', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'ст.л.');

    v_iid := _tmp_find_or_create_ingredient('оливковое масло', 'olive oil', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'ст.л.');

    v_iid := _tmp_find_or_create_ingredient('соль', 'salt', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');

    v_iid := _tmp_find_or_create_ingredient('укроп', 'dill', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');
  END IF;
  SELECT id INTO r35 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с лососем';


  -- ── 36. Судак, запечённый с картофелем ──────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Судак, запечённый с картофелем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Судак, запечённый с картофелем',
            'Картофель нарезать дольками, посолить, сбрызнуть маслом и выложить на противень. Судака очистить, разрезать на порционные куски, посолить, выложить поверх картофеля. Сверху — кружки помидора. Сбрызнуть маслом, посыпать укропом. Запекать 40–45 минут при 180°C.',
            3)
    RETURNING id INTO v_rid;

    v_iid := _tmp_find_or_create_ingredient('судак', 'pike perch', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 600, 'г');

    v_iid := _tmp_find_or_create_ingredient('картофель', 'potato', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 500, 'г');

    v_iid := _tmp_find_or_create_ingredient('помидор', 'tomato', 'moderate');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 1, 'шт');

    v_iid := _tmp_find_or_create_ingredient('оливковое масло', 'olive oil', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 2, 'ст.л.');

    v_iid := _tmp_find_or_create_ingredient('соль', 'salt', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');

    v_iid := _tmp_find_or_create_ingredient('укроп', 'dill', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');
  END IF;
  SELECT id INTO r36 FROM recipes WHERE user_id = v_user_id AND name = 'Судак, запечённый с картофелем';


  -- ── 37. Курица, тушёная с молодыми кабачками ────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Курица, тушёная с молодыми кабачками') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Курица, тушёная с молодыми кабачками',
            'Куриное филе нарезать кубиками, слегка обжарить на масле 5 минут. Молодые кабачки нарезать полукольцами, помидор — кубиками. Добавить кабачки к курице, через 5 минут добавить помидор. Посолить, влить 100 мл воды, накрыть крышкой и тушить 20–25 минут на небольшом огне. Посыпать зеленью.',
            3)
    RETURNING id INTO v_rid;

    v_iid := _tmp_find_or_create_ingredient('куриное филе', 'chicken fillet', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 400, 'г');

    v_iid := _tmp_find_or_create_ingredient('кабачок молодой', 'young zucchini', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 400, 'г');

    v_iid := _tmp_find_or_create_ingredient('помидор', 'tomato', 'moderate');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 2, 'шт');

    v_iid := _tmp_find_or_create_ingredient('оливковое масло', 'olive oil', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 2, 'ст.л.');

    v_iid := _tmp_find_or_create_ingredient('вода', 'water', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, 100, 'мл');

    v_iid := _tmp_find_or_create_ingredient('соль', 'salt', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');

    v_iid := _tmp_find_or_create_ingredient('укроп', 'dill', 'low');
    INSERT INTO recipe_ingredients (recipe_id, ingredient_id, amount, unit) VALUES (v_rid, v_iid, NULL, 'по вкусу');
  END IF;
  SELECT id INTO r37 FROM recipes WHERE user_id = v_user_id AND name = 'Курица, тушёная с молодыми кабачками';


  -- ══════════════════════════════════════════════════════════════════════════
  -- ЧАСТЬ 2: RESOLVE EXISTING RECIPE IDs
  -- ══════════════════════════════════════════════════════════════════════════

  SELECT id INTO r_omlet    FROM recipes WHERE user_id = v_user_id AND name = 'Омлет с кабачком и помидором';
  SELECT id INTO r_rolls    FROM recipes WHERE user_id = v_user_id AND name = 'Рисовые роллы с тунцем';
  SELECT id INTO r_blini    FROM recipes WHERE user_id = v_user_id AND name = 'Рисовые блины на безлактозном молоке';
  SELECT id INTO r_eggs_tom FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с помидором и зелёным луком';
  SELECT id INTO r_pot_tuna FROM recipes WHERE user_id = v_user_id AND name = 'Запечённый картофель с тунцем и сметаной';
  SELECT id INTO r_quinoa   FROM recipes WHERE user_id = v_user_id AND name = 'Киноа с безлактозным творогом и ананасом';
  SELECT id INTO r_tuna_sal FROM recipes WHERE user_id = v_user_id AND name = 'Салат с тунцем, кукурузой, огурцом и оливками';
  SELECT id INTO r_eggs_pep FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с болгарским перцем';
  SELECT id INTO r_buck_zuc FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с куриным филе и кабачком';
  SELECT id INTO r_fish_pot FROM recipes WHERE user_id = v_user_id AND name = 'Запечённая рыба с картофелем и морковью';


  -- ══════════════════════════════════════════════════════════════════════════
  -- ЧАСТЬ 3: MEAL PLANS — НЕДЕЛЯ 4 (2026-06-08)
  -- ══════════════════════════════════════════════════════════════════════════

  -- Удалить записи за неделю 2026-06-08 (добавленную ошибочно)
  DELETE FROM meal_plans
  WHERE user_id = v_user_id AND week_start = '2026-06-08';

  -- Очистить существующие планы для целевой недели (идемпотентность)
  DELETE FROM meal_plans
  WHERE user_id = v_user_id AND week_start = v_week;

  INSERT INTO meal_plans (user_id, week_start, day_of_week, meal_type, recipe_id) VALUES
  -- Понедельник (0)
    (v_user_id, v_week, 0, 'breakfast', r32),
    (v_user_id, v_week, 0, 'lunch',     r33),
    (v_user_id, v_week, 0, 'dinner',    r34),
  -- Вторник (1) — остатки супа
    (v_user_id, v_week, 1, 'breakfast', r_omlet),
    (v_user_id, v_week, 1, 'lunch',     r_rolls),
    (v_user_id, v_week, 1, 'dinner',    r34),
  -- Среда (2)
    (v_user_id, v_week, 2, 'breakfast', r_blini),
    (v_user_id, v_week, 2, 'lunch',     r33),
    (v_user_id, v_week, 2, 'dinner',    r35),
  -- Четверг (3) — остатки гречки с лососем
    (v_user_id, v_week, 3, 'breakfast', r_eggs_tom),
    (v_user_id, v_week, 3, 'lunch',     r_pot_tuna),
    (v_user_id, v_week, 3, 'dinner',    r35),
  -- Пятница (4)
    (v_user_id, v_week, 4, 'breakfast', r32),
    (v_user_id, v_week, 4, 'lunch',     r36),
    (v_user_id, v_week, 4, 'dinner',    r37),
  -- Суббота (5) — остатки курицы
    (v_user_id, v_week, 5, 'breakfast', r_quinoa),
    (v_user_id, v_week, 5, 'lunch',     r_tuna_sal),
    (v_user_id, v_week, 5, 'dinner',    r37),
  -- Воскресенье (6)
    (v_user_id, v_week, 6, 'breakfast', r_eggs_pep),
    (v_user_id, v_week, 6, 'lunch',     r_buck_zuc),
    (v_user_id, v_week, 6, 'dinner',    r_fish_pot);

END $$;


-- ── Удалить временную функцию ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS _tmp_find_or_create_ingredient(text, text, text);
