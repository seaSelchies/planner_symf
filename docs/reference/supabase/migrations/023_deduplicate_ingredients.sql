-- Migration 023: Deduplicate ingredients — точные совпадения и семантические дубли
-- Для каждого дубля: перепривязать FK → убрать кастомную запись.

DO $$
DECLARE
  custom_id   uuid;
  keep_id     uuid;
BEGIN

  -- ── Хелпер: перепривязать и удалить ─────────────────────────────────────
  -- Используем явные пары (custom_id → keep_id) по результатам анализа CSV.

  FOR custom_id, keep_id IN VALUES
    -- соль (unknown)         → salt / соль (low)
    ('24767aaf-642c-4be4-8cd5-958eccde0b55'::uuid, '313972ba-0248-4957-a018-97b4619efbfa'::uuid),
    -- укроп (unknown)        → dill / укроп (low)
    ('4930f6f7-4f95-4aa8-8824-f819205a3d47'::uuid, '2e403e47-280a-4228-b594-cb62e854127d'::uuid),
    -- сливочное масло (unk.) → butter / сливочное масло (low)
    ('1dd15db8-2e67-4e24-adb0-1bc01c75c763'::uuid, '33ee045f-fd21-4ea2-89bc-991b8177a27b'::uuid),
    -- безлактозное масло     → butter / сливочное масло (low, лактоза в масле минимальна)
    ('498b87c1-6bcc-484f-81a6-7e2510e87c0b'::uuid, '33ee045f-fd21-4ea2-89bc-991b8177a27b'::uuid),
    -- баклажан (unknown)     → eggplant / баклажан (low)
    ('3013f133-2454-404c-ae16-c521ce125368'::uuid, '2412e51e-11d9-48ac-ad4b-9e78504dfa56'::uuid),
    -- гречка (unknown)       → buckwheat / гречка (low)
    ('25fa8819-2ab4-42a2-a46c-3b4bec1ff1e5'::uuid, 'dbcd2ebe-729a-40fb-b834-3d7b174a5b47'::uuid),
    -- кабачок (unknown)      → zucchini / кабачок (low)
    ('96d33bf4-7403-46e5-9a9c-2c140d347d66'::uuid, '5167da43-223d-45b5-a4b0-53a4f524829f'::uuid),
    -- морковь (unknown)      → carrot / морковь (low)
    ('74f92c67-9e6d-4a33-9602-88ad766f9f5d'::uuid, '296b054d-3c78-4c88-9c7e-fb6f3b836492'::uuid),
    -- яйцо (unknown)         → egg / яйцо (low)
    ('6e225101-6919-485c-ad29-68593bdef4e9'::uuid, '86c39775-3845-4b30-8e3a-220da82d22a8'::uuid),
    -- яйца (plural, unknown) → egg / яйцо (low)
    ('dbbb5480-125a-4406-b5df-e1dea0e7193f'::uuid, '86c39775-3845-4b30-8e3a-220da82d22a8'::uuid),
    -- рисовая мука (unknown) → rice flour / рисовая мука (low)
    ('716264ce-50a0-4ed0-8ca0-f6356b1b7f08'::uuid, '2dbe8f21-b1d6-4409-b9cb-861c946603ed'::uuid),
    -- пшеничная мука (unk.)  → wheat flour / пшеничная мука (high)
    ('42335523-597a-4855-9f2f-a0495962e096'::uuid, '5e3e9bd2-6fa5-44b8-b397-7d0bb646e732'::uuid),
    -- киноа (unknown)        → quinoa / киноа (low)
    ('43a8f4df-4db5-40fd-bc42-cc6b78e5c1c2'::uuid, '57a6a422-3b41-4c6a-ab48-69a4687ae2d5'::uuid),
    -- сахар (unknown)        → sugar (white, cane) / сахар (белый, тростниковый) (low)
    ('2f83fce5-d235-44bc-97a3-8cbeaccd8cce'::uuid, '434c2a2c-d7f0-4ecb-9fba-42f39d1f45d8'::uuid),
    -- лавровый лист (unk.)   → bay leaf / лавровый лист (low)
    ('cb2b0c0c-0638-42f9-869b-a16099103e69'::uuid, 'a97d4a30-7b07-4ff6-aff8-7e30887fe819'::uuid),
    -- картофель (unknown)    → potato / картофель (low)
    ('a567fac5-f2d0-40b8-8270-cda7bcd6923f'::uuid, 'f38f0f6c-422b-4a68-a483-7aecacb961ee'::uuid),
    -- батат (unknown)        → sweet potato / батат (moderate)
    ('cdd04a51-1f86-4bcd-8414-65532fcca109'::uuid, 'c1559c07-80a2-4b00-b3e9-933c9c901154'::uuid),
    -- огурец (unknown)       → cucumber / огурец (low)
    ('8d70a64c-68e6-439d-9ee1-f83b9e3232d1'::uuid, '3ab7916b-adb5-4f32-a8e3-12197a01058b'::uuid),
    -- рис (unknown)          → рис (белый, длиннозёрный) (low)
    ('6f2f8618-e563-4ccb-a1e2-331e71ab1428'::uuid, 'f0fea603-f05f-4bd5-9443-5b383180defa'::uuid),
    -- банан (спелый) (unk.)  → banana (ripe) / банан (спелый) (high)
    ('f3bb4da2-d6a9-44f6-9dbc-7cd5bd730ab4'::uuid, '10b6cab7-c6be-4997-9dfc-2d426c3ecee4'::uuid),
    -- тунец консервированный → tuna (canned in water) (low)
    ('8526362c-5812-4b04-ab4b-3209b34b1a87'::uuid, '835e8d0d-6c4f-4b01-9973-7f1e331eecf2'::uuid),
    -- молоко (unknown)       → regular cow milk / обычное коровье молоко (high)
    ('34561f33-cd5c-44cb-a751-fac6ad2c7cb7'::uuid, 'f9c09685-c4ce-4e11-bf9b-b8781a7f2b3d'::uuid),
    -- безлактозное молоко    → lactose-free milk / молоко без лактозы (low)
    ('d5cbce20-1a24-426b-a839-b42b9ae8305e'::uuid, 'fe656547-de43-4867-ace5-1a16ab89e830'::uuid),
    -- подсолнечное масло     → vegetable oil / растительное масло (low)
    ('a2c33481-38db-4fb0-bfc8-4553ede23e09'::uuid, '573fcc84-eff4-47da-911b-48b195044822'::uuid),
    -- маслины                → olives / оливки (low)
    ('4796acce-e9fd-4529-abe8-2a3e649bf208'::uuid, '4aba58e0-3f27-431f-b796-f4d424c4ca89'::uuid),
    -- помидор (unknown)      → tomato (common) / томат (обычный) (low)
    ('389209aa-4fe5-4d1f-9834-332a5bb1dafa'::uuid, '5a1350c6-d8ce-49a5-803c-6b70c235f5bf'::uuid),
    -- болгарский перец (unk) → capsicum (red bell pepper) / болгарский перец (красный) (low)
    ('7f9c5319-0621-42b9-9d3e-b9ff5ef3432c'::uuid, '520f907c-cbdf-4834-87f0-6ff1d4832508'::uuid),
    -- сок лимона             → lemon juice / лимонный сок (low)
    ('448df83d-fa09-4cea-a6a1-5de5778a5160'::uuid, '5ac50ae4-4661-4b96-9db3-c2fcdb1f87f4'::uuid),
    -- безлактозный творог 5% → безлактозный творог (оба unknown — оставляем один)
    ('058a0119-0d85-46d6-859b-590cb23fb05e'::uuid, '1b735fdf-b536-493a-9062-f8f2018db359'::uuid),
    -- консервированный ананас → pineapple / ананас (low)
    ('c602441d-ba39-4ce6-98c5-477b50fd30dc'::uuid, '24d08412-4b4f-4c44-b101-1dfa27928a09'::uuid),
    -- консервированная кукуруза → corn (tinned) / кукуруза (консервированная) (low)
    ('f3758404-c222-4e7e-afb4-a53a1bbaa448'::uuid, '7b65a715-790d-4360-86ce-c61112f94799'::uuid)
  LOOP
    UPDATE recipe_ingredients   SET ingredient_id = keep_id WHERE ingredient_id = custom_id;
    UPDATE meal_log_ingredients SET ingredient_id = keep_id WHERE ingredient_id = custom_id;
    DELETE FROM ingredients WHERE id = custom_id;
  END LOOP;

END $$;

SELECT COUNT(*) AS ingredients_after_dedup FROM ingredients;
