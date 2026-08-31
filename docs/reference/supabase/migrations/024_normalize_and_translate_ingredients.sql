-- Migration 024: Нормализация регистра + добавление переводов

-- ── 1. Lowercase всех имён ────────────────────────────────────────────────
UPDATE ingredients SET name_en = LOWER(name_en) WHERE name_en IS NOT NULL;
UPDATE ingredients SET name_ru = LOWER(name_ru) WHERE name_ru IS NOT NULL;

-- ── 2. Добавить name_ru для FODMAP-записей у которых его нет ─────────────

-- cucumber
UPDATE ingredients SET name_ru = 'огурец'    WHERE id = '3ab7916b-adb5-4f32-a8e3-12197a01058b';
-- potato
UPDATE ingredients SET name_ru = 'картофель' WHERE id = 'f38f0f6c-422b-4a68-a483-7aecacb961ee';

-- ── 3. Добавить name_en для кастомных записей без него ────────────────────

UPDATE ingredients SET name_en = 'lactose-free cottage cheese'
  WHERE id = '1b735fdf-b536-493a-9062-f8f2018db359';

UPDATE ingredients SET name_en = 'rice paper'
  WHERE id = '0c386e50-7be4-4891-bdfe-5c6395229333';

UPDATE ingredients SET name_en = 'baking powder'
  WHERE id = 'a56b3ea4-d1ca-4a51-8f10-7d48e366240a';

UPDATE ingredients SET name_en = 'lactose-free sour cream'
  WHERE id = '4a58c885-d205-4359-a6bf-1e663f72b737';

UPDATE ingredients SET name_en = 'chicken fillet'
  WHERE id = '6aef300e-69e6-450a-8d9e-add9a2bab3fa';

UPDATE ingredients SET name_en = 'ground chicken'
  WHERE id = '66366a4d-8a1a-4a5f-9ffb-1c1f5b33d485';

UPDATE ingredients SET name_en = 'black pepper'
  WHERE id = '9ef8e35a-cbed-4460-80e2-c208d18f9396';

UPDATE ingredients SET name_en = 'green onion'
  WHERE id = '90d12629-6c51-471f-8dcd-85e77e34859d';

UPDATE ingredients SET name_en = 'cheese'
  WHERE id = 'd1d1d6ce-b1f9-4087-bbf6-1c37f2df609f';

UPDATE ingredients SET name_en = 'fish'
  WHERE id = '2103cc38-8f07-42c1-91d7-974ba38a6c08';

UPDATE ingredients SET name_en = 'bread'
  WHERE id = '5ba9c839-e907-4e7f-a450-243681c2584b';

UPDATE ingredients SET name_en = 'chicken liver'
  WHERE id = 'd075d9b5-7e8d-4625-b3dd-29a94de4bb92';

UPDATE ingredients SET name_en = 'muffin / cupcake'
  WHERE id = '6eb27001-fab9-45cc-99a7-1c34dfe22548';

UPDATE ingredients SET name_en = 'salmon steaks'
  WHERE id = 'd8c70211-36bc-4dae-a71d-8ecc8ee26d69';

UPDATE ingredients SET name_en = 'honey cake'
  WHERE id = 'c941061f-a7d8-496f-99a2-d9464ecdcdd0';

UPDATE ingredients SET name_en = 'turkish delight'
  WHERE id = 'b18e2a7e-991f-4854-b30f-d1f666805c82';

UPDATE ingredients SET name_en = 'filo pastry'
  WHERE id = 'a8312748-e5fa-495a-8944-b5b26ca04cd0';

UPDATE ingredients SET name_en = 'turkey fillet'
  WHERE id = 'f4916732-8da8-4dd0-bfa6-080f12b248a6';

UPDATE ingredients SET name_en = 'vanilla sugar'
  WHERE id = 'c49a4133-6243-4450-b357-ec7691e1dacf';

UPDATE ingredients SET name_en = 'frozen green beans'
  WHERE id = 'c0ca0719-bf97-4130-b415-4e8da14e2ce6';

UPDATE ingredients SET name_en = 'lemon tart'
  WHERE id = '157d0b12-dd95-48b6-9498-6faa671c1bbf';

UPDATE ingredients SET name_en = 'chocolate tart'
  WHERE id = 'eee03d1d-02f5-42a4-bc3a-0695adf8c475';

UPDATE ingredients SET name_en = 'cream'
  WHERE id = '491a1e34-f34f-40c7-a0fd-72600514e55a';

UPDATE ingredients SET name_en = 'bulgur wheat'
  WHERE id = 'a3c62c6d-661a-4c14-a355-ddcead8638db';

UPDATE ingredients SET name_en = 'dried date'
  WHERE id = '71763933-0ded-48ad-af95-45cb94eb6ca1';

UPDATE ingredients SET name_en = 'oats'
  WHERE id = '8f5aa745-5fec-4e19-8cbd-2a34e9c41f03';

UPDATE ingredients SET name_en = 'cherries'
  WHERE id = '488fccb1-3c58-43ca-a0a6-1c0d26f6d29b';

UPDATE ingredients SET name_en = 'canned pineapple'
  WHERE id = 'c602441d-ba39-4ce6-98c5-477b50fd30dc';

-- ── 4. Ещё несколько семантических мержей (пропущены в 023) ──────────────

-- сыр фета (custom) → feta cheese (оригинал)
UPDATE recipe_ingredients   SET ingredient_id = 'be93bfed-3f89-4809-8c0f-b9a871478cd4'
  WHERE ingredient_id = '82c5b65f-f833-4fd1-be3b-1bf9eea0f878';
UPDATE meal_log_ingredients SET ingredient_id = 'be93bfed-3f89-4809-8c0f-b9a871478cd4'
  WHERE ingredient_id = '82c5b65f-f833-4fd1-be3b-1bf9eea0f878';
DELETE FROM ingredients WHERE id = '82c5b65f-f833-4fd1-be3b-1bf9eea0f878';

-- вишня (custom) → вишня/черешня (оригинал, high)
UPDATE recipe_ingredients   SET ingredient_id = '1cdb4c3f-e154-4bd0-ae06-feaea9e7b893'
  WHERE ingredient_id = '488fccb1-3c58-43ca-a0a6-1c0d26f6d29b';
UPDATE meal_log_ingredients SET ingredient_id = '1cdb4c3f-e154-4bd0-ae06-feaea9e7b893'
  WHERE ingredient_id = '488fccb1-3c58-43ca-a0a6-1c0d26f6d29b';
DELETE FROM ingredients WHERE id = '488fccb1-3c58-43ca-a0a6-1c0d26f6d29b';

-- лук (custom) → onion (brown/white) / лук репчатый (high)
UPDATE recipe_ingredients   SET ingredient_id = '02a5fd1f-e8b6-4856-bdb9-2360063fdd37'
  WHERE ingredient_id = '3e02e35d-ac64-49ff-8d2e-f344026b6a40';
UPDATE meal_log_ingredients SET ingredient_id = '02a5fd1f-e8b6-4856-bdb9-2360063fdd37'
  WHERE ingredient_id = '3e02e35d-ac64-49ff-8d2e-f344026b6a40';
DELETE FROM ingredients WHERE id = '3e02e35d-ac64-49ff-8d2e-f344026b6a40';

SELECT COUNT(*) AS total FROM ingredients;
