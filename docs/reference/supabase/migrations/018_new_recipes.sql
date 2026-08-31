-- Migration 018: Add new recipes — творожные вафли и яблочный пирог с крамблом
-- Run in Supabase SQL Editor
-- Idempotent: skips if recipe already exists

DO $$
DECLARE
  v_user_id  uuid;
  v_rid      uuid;
BEGIN

  -- Resolve user
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'selchies.sea@gmail.com'
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User selchies.sea@gmail.com not found in auth.users';
  END IF;


  -- ── 1. Творожные вафли в вафельнице ─────────────────────────────────────
  -- Source: https://1000.menu/cooking/26246-tvorojnye-vafli-v-vafelnice
  -- Примечание: рецепт содержит пшеничную муку (high) и творог (high lactose).
  -- Для FODMAP-варианта заменить на рисовую муку + безлактозный творог.

  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Творожные вафли в вафельнице') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Творожные вафли в вафельнице',
            'Творог протереть через сито. Взбить сливочное масло с сахаром добела, добавить яйца по одному. Смешать с творогом. Постепенно всыпать муку с разрыхлителем, перемешать до исчезновения комочков. Выпекать в разогретой вафельнице около 5 минут до золотистого цвета.',
            4)
    RETURNING id INTO v_rid;

    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'безлактозный творог',   200,  'г'),
      (v_rid, 'яйцо',                    2,  'шт'),
      (v_rid, 'сахар',                   3,  'ст.л.'),
      (v_rid, 'ванильный сахар',          1,  'ч.л.'),
      (v_rid, 'соль',                  NULL,  'щепотка'),
      (v_rid, 'пшеничная мука',         100,  'г'),
      (v_rid, 'разрыхлитель',             1,  'ч.л.'),
      (v_rid, 'сливочное масло',          50,  'г');

    -- Link to fodmap_ingredients where matches exist
    UPDATE recipe_ingredients ri
    SET fodmap_ingredient_id = fi.id
    FROM fodmap_ingredients fi
    WHERE ri.recipe_id = v_rid
      AND (
        (ri.ingredient_name = 'яйцо'            AND fi.translations->>'en' = 'egg') OR
        (ri.ingredient_name = 'сахар'           AND fi.translations->>'ru' = 'сахар (белый, тростниковый)') OR
        (ri.ingredient_name = 'сливочное масло' AND fi.translations->>'ru' = 'сливочное масло') OR
        (ri.ingredient_name = 'пшеничная мука'  AND fi.translations->>'ru' = 'пшеничная мука') OR
        (ri.ingredient_name = 'ванильный сахар' AND fi.translations->>'ru' = 'экстракт ванили')
      );
  END IF;


  -- ── 2. Яблочный пирог с крамблом ────────────────────────────────────────
  -- Рецепт предоставлен пользователем
  -- Примечание: содержит яблоки (high — фруктоза+сорбит), пшеничную муку (high),
  -- обычное молоко (high — лактоза). Для FODMAP заменить молоко безлактозным,
  -- муку рисовой, яблоки — допустимыми фруктами.

  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Яблочный пирог с крамблом') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Яблочный пирог с крамблом',
            'Яблоки очистить и нарезать тонкими пластинками. Смешать яйца, сахар, соль. Добавить молоко и растопленное (не горячее) сливочное масло, перемешать венчиком. Всыпать муку с разрыхлителем, размешать до исчезновения комочков — тесто получится жидким и однородным. Соединить яблоки с тестом, вылить в форму. Для крамбла перетереть пальцами масло, муку и сахар в крошку, посыпать сверху. Выпекать 50 минут при 180°C.',
            6)
    RETURNING id INTO v_rid;

    -- Тесто
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'яйцо',              2,    'шт'),
      (v_rid, 'сахар',             50,   'г'),
      (v_rid, 'ванильный сахар',   10,   'г'),
      (v_rid, 'соль',            NULL,   'щепотка'),
      (v_rid, 'пшеничная мука',    70,   'г'),
      (v_rid, 'разрыхлитель',       1,   'ч.л.'),
      (v_rid, 'сливочное масло',   30,   'г'),
      (v_rid, 'молоко',           100,   'мл'),
      (v_rid, 'яблоко',           500,   'г'),
    -- Крамбл
      (v_rid, 'сливочное масло (крамбл)', 20, 'г'),
      (v_rid, 'пшеничная мука (крамбл)',  50, 'г'),
      (v_rid, 'сахар (крамбл)',           15, 'г');

    -- Link to fodmap_ingredients
    UPDATE recipe_ingredients ri
    SET fodmap_ingredient_id = fi.id
    FROM fodmap_ingredients fi
    WHERE ri.recipe_id = v_rid
      AND (
        (ri.ingredient_name = 'яйцо'             AND fi.translations->>'en' = 'egg') OR
        (ri.ingredient_name IN ('сахар', 'сахар (крамбл)') AND fi.translations->>'ru' = 'сахар (белый, тростниковый)') OR
        (ri.ingredient_name IN ('сливочное масло', 'сливочное масло (крамбл)') AND fi.translations->>'ru' = 'сливочное масло') OR
        (ri.ingredient_name IN ('пшеничная мука', 'пшеничная мука (крамбл)') AND fi.translations->>'ru' = 'пшеничная мука') OR
        (ri.ingredient_name = 'ванильный сахар'  AND fi.translations->>'ru' = 'экстракт ванили') OR
        (ri.ingredient_name = 'молоко'           AND fi.translations->>'ru' = 'обычное коровье молоко') OR
        (ri.ingredient_name = 'яблоко'           AND fi.translations->>'ru' = 'яблоко')
      );
  END IF;


  -- ── 3. Шарлотка с яблоками ──────────────────────────────────────────────
  -- Source: https://www.russianfood.com/recipes/recipe.php?rid=147496
  -- Классический бисквитный пирог с яблоками.
  -- Примечание: содержит пшеничную муку (high) и яблоки (high — фруктоза+сорбит).
  -- Для FODMAP: заменить муку рисовой, яблоки — грушей или ананасом.

  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Шарлотка с яблоками') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Шарлотка с яблоками',
            'Взбить яйца с сахаром и солью в светлую густую массу (взбивать до тех пор, пока след от венчика держится 1–2 секунды). Частями просеять муку и аккуратно вмешать лопаткой движениями снизу вверх. Яблоки нарезать дольками или кубиками. Форму (22 см) смазать маслом и припылить мукой. Вылить половину теста, разложить половину яблок, залить остатком теста, сверху — оставшиеся яблоки. По желанию присыпать корицей. Выпекать 30–40 минут при 180°C до сухой шпажки.',
            6)
    RETURNING id INTO v_rid;

    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'яйцо',             4,    'шт'),
      (v_rid, 'сахар',          200,    'г'),
      (v_rid, 'соль',          NULL,    'щепотка'),
      (v_rid, 'пшеничная мука', 150,    'г'),
      (v_rid, 'яблоко',         500,    'г'),
      (v_rid, 'корица',        NULL,    'по желанию');

    UPDATE recipe_ingredients ri
    SET fodmap_ingredient_id = fi.id
    FROM fodmap_ingredients fi
    WHERE ri.recipe_id = v_rid
      AND (
        (ri.ingredient_name = 'яйцо'           AND fi.translations->>'en' = 'egg') OR
        (ri.ingredient_name = 'сахар'          AND fi.translations->>'ru' = 'сахар (белый, тростниковый)') OR
        (ri.ingredient_name = 'пшеничная мука' AND fi.translations->>'ru' = 'пшеничная мука') OR
        (ri.ingredient_name = 'яблоко'         AND fi.translations->>'ru' = 'яблоко')
      );
  END IF;

END $$;
