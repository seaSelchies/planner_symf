-- ============================================================
-- Migration 013: Leftover slots in meal_plans
-- ============================================================
-- Adds is_leftover flag and a reference back to the source slot.
-- Leftover slots are excluded from the shopping list ingredient fetch.
-- ============================================================

ALTER TABLE public.meal_plans
  ADD COLUMN IF NOT EXISTS is_leftover boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS leftover_source_id uuid REFERENCES public.meal_plans(id) ON DELETE SET NULL;
