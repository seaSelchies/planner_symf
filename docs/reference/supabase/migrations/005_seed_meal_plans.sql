-- ============================================================
-- Migration 005: Seed meal plans (v2)
-- Starts from Saturday 2026-05-23 (tomorrow)
-- week_start is always the Monday of that week (app requirement)
--
-- Week A: 2026-05-18  →  only Sat (day 5) + Sun (day 6)
-- Week B: 2026-05-25  →  full Mon–Sun (Week 2 content)
-- Week C: 2026-06-01  →  full Mon–Sun (Week 3 content)
--
-- Run in Supabase SQL Editor.
-- Safe to re-run: deletes existing rows for these weeks first.
-- ============================================================

DO $$
DECLARE
  v_user_id uuid;

  r1  uuid; r2  uuid; r4  uuid; r6  uuid; r8  uuid;
  r9  uuid; r12 uuid; r13 uuid; r18 uuid; r19 uuid;
  r20 uuid; r21 uuid; r22 uuid; r23 uuid; r24 uuid;
  r25 uuid; r26 uuid; r27 uuid; r28 uuid; r29 uuid;
  r30 uuid; r31 uuid;

BEGIN
  SELECT id INTO v_user_id FROM auth.users WHERE email = 'selchies.sea@gmail.com';
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'User not found'; END IF;

  -- Clean up old data for these three weeks
  DELETE FROM meal_plans
  WHERE user_id = v_user_id
    AND week_start IN ('2026-05-18', '2026-05-25', '2026-06-01');

  -- Resolve recipe IDs
  SELECT id INTO r1  FROM recipes WHERE user_id = v_user_id AND name = 'Рисовая каша на безлактозном молоке с ананасом';
  SELECT id INTO r2  FROM recipes WHERE user_id = v_user_id AND name = 'Салат с тунцем, кукурузой, огурцом и оливками';
  SELECT id INTO r4  FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с помидором и зелёным луком';
  SELECT id INTO r6  FROM recipes WHERE user_id = v_user_id AND name = 'Запечённый картофель с тунцем и сметаной';
  SELECT id INTO r8  FROM recipes WHERE user_id = v_user_id AND name = 'Рисовые роллы с тунцем (рисовая бумага)';
  SELECT id INTO r9  FROM recipes WHERE user_id = v_user_id AND name = 'Рисовые блины на безлактозном молоке';
  SELECT id INTO r12 FROM recipes WHERE user_id = v_user_id AND name = 'Курица, запечённая с картофелем и кабачком';
  SELECT id INTO r13 FROM recipes WHERE user_id = v_user_id AND name = 'Киноа с безлактозным творогом и ананасом';
  SELECT id INTO r18 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с куриным филе и кабачком';
  SELECT id INTO r19 FROM recipes WHERE user_id = v_user_id AND name = 'Яичница с болгарским перцем';
  SELECT id INTO r20 FROM recipes WHERE user_id = v_user_id AND name = 'Суп из кабачка с курицей';
  SELECT id INTO r21 FROM recipes WHERE user_id = v_user_id AND name = 'Куриные котлеты на рисовой муке';
  SELECT id INTO r22 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с курицей и болгарским перцем';
  SELECT id INTO r23 FROM recipes WHERE user_id = v_user_id AND name = 'Тушёная рыба с помидорами';
  SELECT id INTO r24 FROM recipes WHERE user_id = v_user_id AND name = 'Картофельные оладьи на рисовой муке';
  SELECT id INTO r25 FROM recipes WHERE user_id = v_user_id AND name = 'Фаршированный перец с киноа и курицей';
  SELECT id INTO r26 FROM recipes WHERE user_id = v_user_id AND name = 'Омлет с кабачком и помидором';
  SELECT id INTO r27 FROM recipes WHERE user_id = v_user_id AND name = 'Суп с бататом и курицей';
  SELECT id INTO r28 FROM recipes WHERE user_id = v_user_id AND name = 'Индейка со стручковой фасолью';
  SELECT id INTO r29 FROM recipes WHERE user_id = v_user_id AND name = 'Гречка с индейкой';
  SELECT id INTO r30 FROM recipes WHERE user_id = v_user_id AND name = 'Лосось, запечённый с картофелем';
  SELECT id INTO r31 FROM recipes WHERE user_id = v_user_id AND name = 'Курица с баклажаном и помидорами';

  -- ── WEEK A: 2026-05-18 — только суббота и воскресенье ──────
  INSERT INTO meal_plans (user_id, week_start, day_of_week, meal_type, recipe_id) VALUES
  -- Суббота 23 мая (day 5)
    (v_user_id, '2026-05-18', 5, 'breakfast', r1),
    (v_user_id, '2026-05-18', 5, 'lunch',     r2),
    (v_user_id, '2026-05-18', 5, 'dinner',    r12),
  -- Воскресенье 24 мая (day 6)
    (v_user_id, '2026-05-18', 6, 'breakfast', r4),
    (v_user_id, '2026-05-18', 6, 'lunch',     r18),
    (v_user_id, '2026-05-18', 6, 'dinner',    r2);

  -- ── WEEK B: 2026-05-25 — полная неделя (меню нед. 2) ───────
  INSERT INTO meal_plans (user_id, week_start, day_of_week, meal_type, recipe_id) VALUES
  -- Понедельник (0)
    (v_user_id, '2026-05-25', 0, 'breakfast', r19),
    (v_user_id, '2026-05-25', 0, 'lunch',     r2),
    (v_user_id, '2026-05-25', 0, 'dinner',    r20),
  -- Вторник (1)
    (v_user_id, '2026-05-25', 1, 'breakfast', r1),
    (v_user_id, '2026-05-25', 1, 'lunch',     r6),
    (v_user_id, '2026-05-25', 1, 'dinner',    r20),
  -- Среда (2)
    (v_user_id, '2026-05-25', 2, 'breakfast', r9),
    (v_user_id, '2026-05-25', 2, 'lunch',     r21),
    (v_user_id, '2026-05-25', 2, 'dinner',    r22),
  -- Четверг (3)
    (v_user_id, '2026-05-25', 3, 'breakfast', r4),
    (v_user_id, '2026-05-25', 3, 'lunch',     r21),
    (v_user_id, '2026-05-25', 3, 'dinner',    r22),
  -- Пятница (4)
    (v_user_id, '2026-05-25', 4, 'breakfast', r13),
    (v_user_id, '2026-05-25', 4, 'lunch',     r23),
    (v_user_id, '2026-05-25', 4, 'dinner',    r25),
  -- Суббота (5)
    (v_user_id, '2026-05-25', 5, 'breakfast', r24),
    (v_user_id, '2026-05-25', 5, 'lunch',     r23),
    (v_user_id, '2026-05-25', 5, 'dinner',    r25),
  -- Воскресенье (6)
    (v_user_id, '2026-05-25', 6, 'breakfast', r24),
    (v_user_id, '2026-05-25', 6, 'lunch',     r8),
    (v_user_id, '2026-05-25', 6, 'dinner',    r12);

  -- ── WEEK C: 2026-06-01 — полная неделя (меню нед. 3) ───────
  INSERT INTO meal_plans (user_id, week_start, day_of_week, meal_type, recipe_id) VALUES
  -- Понедельник (0)
    (v_user_id, '2026-06-01', 0, 'breakfast', r26),
    (v_user_id, '2026-06-01', 0, 'lunch',     r2),
    (v_user_id, '2026-06-01', 0, 'dinner',    r27),
  -- Вторник (1)
    (v_user_id, '2026-06-01', 1, 'breakfast', r9),
    (v_user_id, '2026-06-01', 1, 'lunch',     r6),
    (v_user_id, '2026-06-01', 1, 'dinner',    r27),
  -- Среда (2)
    (v_user_id, '2026-06-01', 2, 'breakfast', r1),
    (v_user_id, '2026-06-01', 2, 'lunch',     r28),
    (v_user_id, '2026-06-01', 2, 'dinner',    r29),
  -- Четверг (3)
    (v_user_id, '2026-06-01', 3, 'breakfast', r4),
    (v_user_id, '2026-06-01', 3, 'lunch',     r28),
    (v_user_id, '2026-06-01', 3, 'dinner',    r29),
  -- Пятница (4)
    (v_user_id, '2026-06-01', 4, 'breakfast', r13),
    (v_user_id, '2026-06-01', 4, 'lunch',     r2),
    (v_user_id, '2026-06-01', 4, 'dinner',    r30),
  -- Суббота (5)
    (v_user_id, '2026-06-01', 5, 'breakfast', r24),
    (v_user_id, '2026-06-01', 5, 'lunch',     r8),
    (v_user_id, '2026-06-01', 5, 'dinner',    r31),
  -- Воскресенье (6)
    (v_user_id, '2026-06-01', 6, 'breakfast', r19),
    (v_user_id, '2026-06-01', 6, 'lunch',     r18),
    (v_user_id, '2026-06-01', 6, 'dinner',    r31);

END $$;
