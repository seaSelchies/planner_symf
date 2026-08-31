-- Run in Supabase SQL Editor
-- Seeds all FODMAP meal plan recipes for user selchies.sea@gmail.com
-- Idempotent: skips any recipe already present (matched by user_id + name)

DO $$
DECLARE
  v_user_id  uuid;
  v_rid      uuid;
BEGIN

  -- ── 0. Resolve user ──────────────────────────────────────────────────────
  SELECT id INTO v_user_id
  FROM auth.users
  WHERE email = 'selchies.sea@gmail.com'
  LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User selchies.sea@gmail.com not found in auth.users';
  END IF;


  -- ── 1. Рисовая каша на безлактозном молоке с ананасом ───────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Рисовая каша на безлактозном молоке с ананасом') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Рисовая каша на безлактозном молоке с ананасом',
            'Рис промыть до прозрачной воды. Залить молоком и водой, варить 15–20 минут на среднем огне, помешивая. Добавить масло и соль. Подавать с кусочками ананаса.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'рис',                          100,  'г'),
      (v_rid, 'безлактозное молоко',           300,  'мл'),
      (v_rid, 'вода',                          100,  'мл'),
      (v_rid, 'безлактозное масло',             10,  'г'),
      (v_rid, 'соль',                          NULL, 'щепотка'),
      (v_rid, 'консервированный ананас',       NULL, 'кусочков (8–10)');
  END IF;


  -- ── 2. Салат с тунцем, кукурузой, огурцом и оливками ────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Салат с тунцем, кукурузой, огурцом и оливками') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Салат с тунцем, кукурузой, огурцом и оливками',
            'Тунец откинуть на дуршлаг и отжать. Огурец нарезать кубиками, оливки разрезать пополам. Смешать всё, заправить маслом, посолить. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'тунец Calvo в воде',            185,  'г'),
      (v_rid, 'консервированная кукуруза',       3,  'ст.л.'),
      (v_rid, 'огурец',                          1,  'шт'),
      (v_rid, 'чёрные оливки без косточки',    NULL, 'шт (6–8)'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 3. Гречка с куриным филе и морковью ─────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с куриным филе и морковью') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Гречка с куриным филе и морковью',
            'Курицу нарезать, посолить, обжарить 5–7 мин. Морковь натереть, добавить к курице, жарить 5 мин. Гречку промыть, добавить к курице, залить 400 мл кипятка, варить под крышкой 15 мин на малом огне. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'гречка',                        200,  'г'),
      (v_rid, 'куриное филе',                  400,  'г'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'перец',                         NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 4. Яичница с помидором и зелёным луком ──────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с помидором и зелёным луком') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Яичница с помидором и зелёным луком',
            'Масло растопить, обжарить нарезанный помидор 2 мин. Разбить яйца, посолить, жарить 3–4 мин. Посыпать луком и укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'яйца',                            4,  'шт'),
      (v_rid, 'помидор',                          1,  'шт'),
      (v_rid, 'безлактозное масло',              10,  'г'),
      (v_rid, 'зелёный лук (только зелёная часть)', NULL, 'по вкусу'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 5. Картофельный суп с курицей и морковью ────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Картофельный суп с курицей и морковью') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Картофельный суп с курицей и морковью',
            'Курицу отварить 20 мин, вынуть и нарезать. Картофель кубиками, морковь кружочками — варить в бульоне 15 мин. Вернуть курицу, добавить лавровый лист, посолить. Подавать с укропом и луком.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриное филе',                  300,  'г'),
      (v_rid, 'картофель',                       4,  'шт'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'вода',                         1000,  'мл'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'лавровый лист',                NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу'),
      (v_rid, 'зелёный лук (перья)',           NULL, 'по вкусу');
  END IF;


  -- ── 6. Запечённый картофель с тунцем и сметаной ─────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Запечённый картофель с тунцем и сметаной') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Запечённый картофель с тунцем и сметаной',
            'Картофель запекать при 200°C 40–45 мин. Тунец смешать с 2 ст.л. сметаны, посолить. Надрезать картофель крест-накрест, наполнить начинкой из тунца, добавить сметану и оливки, посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'картофель',                       4,  'шт'),
      (v_rid, 'тунец Calvo',                   185,  'г'),
      (v_rid, 'безлактозная сметана',            4,  'ст.л.'),
      (v_rid, 'оливки',                        NULL, 'шт (5–6)'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 7. Рисовый суп с курицей и овощами ──────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Рисовый суп с курицей и овощами') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Рисовый суп с курицей и овощами',
            'Курицу отварить 20 мин, вынуть и нарезать. В бульон добавить рис и морковь кружочками, варить 10 мин. Добавить помидор, ещё 5 мин. Вернуть курицу, посолить. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриное филе',                  300,  'г'),
      (v_rid, 'рис',                             3,  'ст.л.'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'вода',                         1000,  'мл'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 8. Рисовые роллы с тунцем (рисовая бумага) ──────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Рисовые роллы с тунцем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Рисовые роллы с тунцем',
            'Тунец смешать с маслом. Огурцы и морковь нарезать соломкой. Рисовую бумагу размочить в тёплой воде 20–30 сек. Выложить начинку, свернуть рулет. Нарезать на 3–4 части.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'рисовая бумага',                  6,  'листов'),
      (v_rid, 'тунец Calvo',                   185,  'г'),
      (v_rid, 'огурцы',                          2,  'шт'),
      (v_rid, 'морковь',                         1,  'шт'),
      (v_rid, 'зелёный лук (перья)',           NULL, 'по вкусу'),
      (v_rid, 'подсолнечное масло',              1,  'ст.л.');
  END IF;


  -- ── 9. Рисовые блины на безлактозном молоке ─────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Рисовые блины на безлактозном молоке') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Рисовые блины на безлактозном молоке',
            'Яйца взбить с молоком и солью. Добавить муку, дать постоять 5 мин. Жарить на смазанной сковороде по 2 мин с каждой стороны. Подавать со сметаной или ананасом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'рисовая мука',                  150,  'г'),
      (v_rid, 'яйца',                            2,  'шт'),
      (v_rid, 'безлактозное молоко',           250,  'мл'),
      (v_rid, 'соль',                          NULL, 'щепотка'),
      (v_rid, 'безлактозное масло для жарки',   10,  'г');
  END IF;


  -- ── 10. Запечённая рыба с картофелем и морковью ─────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Запечённая рыба с картофелем и морковью') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Запечённая рыба с картофелем и морковью',
            'Картофель ломтиками, морковь кружочками — запекать при 200°C 15 мин с маслом. Рыбу посолить и сбрызнуть лимоном, выложить поверх овощей. Запекать ещё 20–25 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'рыба (горбуша или треска)',      300,  'г'),
      (v_rid, 'картофель',                       4,  'шт'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'сок лимона',                    0.5,  'лимон'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 11. Киноа с курицей и болгарским перцем ─────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Киноа с курицей и болгарским перцем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Киноа с курицей и болгарским перцем',
            'Киноа варить 15 мин. Курицу обжарить 7 мин, добавить перец полосками — 5 мин, затем помидор — 2 мин. Смешать с киноа, посолить. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'киноа',                         200,  'г'),
      (v_rid, 'куриное филе',                  400,  'г'),
      (v_rid, 'красный болгарский перец',        1,  'шт'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 12. Курица, запечённая с картофелем и кабачком ──────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Курица, запечённая с картофелем и кабачком') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Курица, запечённая с картофелем и кабачком',
            'Картофель дольками, кабачок кружочками. Курицу посолить и поперчить. Всё на противень с маслом. Запекать при 200°C 40–45 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриные бёдрышки или филе',     600,  'г'),
      (v_rid, 'картофель',                       4,  'шт'),
      (v_rid, 'кабачок',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'перец',                         NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 13. Киноа с безлактозным творогом и ананасом ────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Киноа с безлактозным творогом и ананасом') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Киноа с безлактозным творогом и ананасом',
            'Киноа варить 12–15 мин. Творог смешать с тёплой киноа. Разложить по тарелкам, сверху ананас. По желанию сбрызнуть маслом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'киноа',                         100,  'г'),
      (v_rid, 'безлактозный творог 5%',        300,  'г'),
      (v_rid, 'консервированный ананас',       NULL, 'кусочков (8–10)'),
      (v_rid, 'подсолнечное масло',              1,  'ч.л.'),
      (v_rid, 'соль',                          NULL, 'щепотка');
  END IF;


  -- ── 14. Салат с куриным филе, кабачком и помидором ──────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Салат с куриным филе, кабачком и помидором') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Салат с куриным филе, кабачком и помидором',
            'Курицу отварить 20 мин, нарезать. Кабачок обжарить 5 мин, остудить. Смешать с помидором, сбрызнуть лимоном, посолить. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриное филе',                  200,  'г'),
      (v_rid, 'кабачок',                       200,  'г'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              1,  'ст.л.'),
      (v_rid, 'сок лимона',                    0.5,  'лимон'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 15. Гречка с запечённой рыбой ───────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с запечённой рыбой') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Гречка с запечённой рыбой',
            'Гречку варить 15 мин. Рыбу посолить, сбрызнуть лимоном и маслом, запекать при 200°C 20–25 мин. Подавать рыбу на гречке с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'гречка',                        200,  'г'),
      (v_rid, 'филе горбуши или трески',        300,  'г'),
      (v_rid, 'подсолнечное масло',              1,  'ст.л.'),
      (v_rid, 'сок лимона',                    0.5,  'лимон'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 16. Яичница с кабачком ───────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с кабачком') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Яичница с кабачком',
            'Кабачок кружочками обжарить 5–7 мин, посолить. Разбить яйца на кабачок, накрыть крышкой и жарить 3–4 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'яйца',                            4,  'шт'),
      (v_rid, 'кабачок',                       200,  'г'),
      (v_rid, 'безлактозное масло',             10,  'г'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 18. Гречка с куриным филе и кабачком ────────────────────────────────
  -- (Recipe #17 intentionally excluded)
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с куриным филе и кабачком') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Гречка с куриным филе и кабачком',
            'Курицу обжарить 5–7 мин. Кабачок кубиками добавить — 5 мин. Гречку промыть, залить 400 мл кипятка, варить 15 мин под крышкой. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'гречка',                        200,  'г'),
      (v_rid, 'куриное филе',                  400,  'г'),
      (v_rid, 'кабачок',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'перец',                         NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 19. Яичница с болгарским перцем ─────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с болгарским перцем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Яичница с болгарским перцем',
            'Перец полосками обжарить 3–4 мин. Помидор кубиками добавить — 1–2 мин. Разбить яйца на овощи, накрыть крышкой, жарить 3–4 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'яйца',                            4,  'шт'),
      (v_rid, 'болгарский перец (красный или жёлтый)', 1, 'шт'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'безлактозное масло',             10,  'г'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 20. Суп из кабачка с курицей ────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Суп из кабачка с курицей') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Суп из кабачка с курицей',
            'Курицу варить 20 мин, вынуть. Морковь кружочками — 5 мин в бульоне. Кабачок кубиками и помидор — добавить, варить 15 мин. Вернуть курицу, посолить. Подавать с укропом и луком.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриное филе',                  300,  'г'),
      (v_rid, 'кабачки',                       400,  'г'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'вода',                         1000,  'мл'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'лавровый лист',                NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу'),
      (v_rid, 'зелёный лук (перья)',           NULL, 'по вкусу');
  END IF;


  -- ── 21. Куриные котлеты на рисовой муке ─────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Куриные котлеты на рисовой муке') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Куриные котлеты на рисовой муке',
            'Фарш смешать с яйцами, мукой, укропом, посолить. Жарить котлеты на масле по 4–5 мин с каждой стороны под крышкой. Получится ~8 котлет.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриный фарш',                  400,  'г'),
      (v_rid, 'яйца',                            2,  'шт'),
      (v_rid, 'рисовая мука',                    3,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'перец',                         NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.');
  END IF;


  -- ── 22. Гречка с курицей и болгарским перцем ────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с курицей и болгарским перцем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Гречка с курицей и болгарским перцем',
            'Курицу обжарить 5–7 мин. Перец полосками — 5 мин. Помидор — 2 мин. Гречку промыть, добавить, залить 400 мл кипятка, варить 15 мин. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'гречка',                        200,  'г'),
      (v_rid, 'куриное филе',                  400,  'г'),
      (v_rid, 'болгарский перец (красный и жёлтый)', 2, 'шт'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 23. Тушёная рыба с помидорами ───────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Тушёная рыба с помидорами') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Тушёная рыба с помидорами',
            'Морковь обжарить 3–4 мин. Помидор добавить — 3 мин. Рыбу посолить, сбрызнуть лимоном, выложить на овощи, тушить под крышкой 12–15 мин. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'филе трески или горбуши',        300,  'г'),
      (v_rid, 'помидоры',                        2,  'шт'),
      (v_rid, 'морковь',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'сок лимона',                    0.5,  'лимон'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 24. Картофельные оладьи на рисовой муке ─────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Картофельные оладьи на рисовой муке') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Картофельные оладьи на рисовой муке',
            'Картофель натереть и хорошо отжать. Смешать с яйцами, мукой, солью. Жарить на масле по 3–4 мин с каждой стороны. Подавать горячими со сметаной.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'картофель',                     400,  'г'),
      (v_rid, 'яйца',                            2,  'шт'),
      (v_rid, 'рисовая мука',                    4,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'щепотка'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'безлактозная сметана',          NULL, 'для подачи');
  END IF;


  -- ── 25. Фаршированный перец с киноа и курицей ───────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Фаршированный перец с киноа и курицей') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Фаршированный перец с киноа и курицей',
            'Киноа отварить. Фарш обжарить с морковью, добавить помидор. Смешать с киноа. Наполнить перцы начинкой. Запекать при 190°C 35–40 мин с 100 мл воды на дне формы.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'болгарский перец',                4,  'шт'),
      (v_rid, 'куриный фарш',                  200,  'г'),
      (v_rid, 'киноа',                         100,  'г'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'морковь',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 26. Омлет с кабачком и помидором ────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Омлет с кабачком и помидором') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Омлет с кабачком и помидором',
            'Кабачок кружочками обжарить 4–5 мин. Помидор добавить — 1–2 мин. Яйца взбить и вылить на овощи. Накрыть, готовить на минимальном огне 5–7 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'яйца',                            4,  'шт'),
      (v_rid, 'кабачок',                       200,  'г'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'безлактозное масло',             10,  'г'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 27. Суп с бататом и курицей ─────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Суп с бататом и курицей') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Суп с бататом и курицей',
            'Курицу варить 20 мин, вынуть. Батат кубиками и морковь кружочками — 15 мин в бульоне. Помидор — 5 мин. Вернуть курицу, посолить. Подавать с укропом и луком.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриное филе',                  300,  'г'),
      (v_rid, 'батат',                         300,  'г'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'помидор',                         1,  'шт'),
      (v_rid, 'вода',                         1000,  'мл'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'лавровый лист',                NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу'),
      (v_rid, 'зелёный лук (перья)',           NULL, 'по вкусу');
  END IF;


  -- ── 28. Индейка со стручковой фасолью ───────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Индейка со стручковой фасолью') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Индейка со стручковой фасолью',
            'Индейку полосками обжарить 5–7 мин. Добавить фасоль (замороженную) — 5 мин. Помидор кубиками — тушить под крышкой 10 мин. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'филе индейки',                  400,  'г'),
      (v_rid, 'замороженная стручковая фасоль', 200, 'г'),
      (v_rid, 'помидоры',                        2,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 29. Гречка с индейкой ────────────────────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с индейкой') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Гречка с индейкой',
            'Индейку обжарить 6–8 мин. Морковь натереть, добавить — 5 мин. Гречку промыть, залить 400 мл кипятка, варить 15 мин. Подавать с укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'гречка',                        200,  'г'),
      (v_rid, 'филе индейки',                  400,  'г'),
      (v_rid, 'морковь',                         2,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 30. Лосось, запечённый с картофелем ─────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Лосось, запечённый с картофелем') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Лосось, запечённый с картофелем',
            'Картофель и морковь запекать при 200°C 15 мин. Лосось посолить, сбрызнуть лимоном, выложить на овощи. Запекать ещё 20–25 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'стейки лосося',                 350,  'г'),
      (v_rid, 'картофель',                       4,  'шт'),
      (v_rid, 'морковь',                         1,  'шт'),
      (v_rid, 'подсолнечное масло',              2,  'ст.л.'),
      (v_rid, 'сок лимона',                    0.5,  'лимон'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;


  -- ── 31. Курица с баклажаном и помидорами ────────────────────────────────
  IF NOT EXISTS (SELECT 1 FROM recipes WHERE user_id = v_user_id AND name = 'Курица с баклажаном и помидорами') THEN
    INSERT INTO recipes (user_id, name, description, servings)
    VALUES (v_user_id,
            'Курица с баклажаном и помидорами',
            'Баклажан кубиками посолить, оставить 10 мин, промыть. Курицу обжарить 5–7 мин. Добавить баклажан — 5 мин. Помидор и лимон — тушить под крышкой 15 мин. Посыпать укропом.',
            2)
    RETURNING id INTO v_rid;
    INSERT INTO recipe_ingredients (recipe_id, ingredient_name, amount, unit) VALUES
      (v_rid, 'куриное филе',                  400,  'г'),
      (v_rid, 'баклажан',                      200,  'г'),
      (v_rid, 'помидоры',                        2,  'шт'),
      (v_rid, 'подсолнечное масло',              1,  'ст.л.'),
      (v_rid, 'сок лимона',                    0.5,  'лимон'),
      (v_rid, 'соль',                          NULL, 'по вкусу'),
      (v_rid, 'укроп',                         NULL, 'по вкусу');
  END IF;

END $$;
