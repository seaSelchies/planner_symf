/**
 * useFodmapStreak
 *
 * A day counts as "FODMAP-safe" if:
 *   – It has data (meal log ingredients OR planned recipe ingredients)
 *   – None of those ingredients is 'moderate' or 'high'
 *
 * Priority per day:
 *   1. meal_log_ingredients  (what was actually eaten, if logged)
 *   2. recipe_ingredients    (what was planned, via meal_plans)
 *
 * The streak is the number of consecutive FODMAP-safe days ending today.
 */

import { useCallback, useState } from 'react';
import { supabase } from '../lib/supabase';

// ── Helpers ───────────────────────────────────────────────────────

function pad(n: number) {
  return String(n).padStart(2, '0');
}

function toISO(date: Date): string {
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

/** Date of a meal_plan row (week_start is Monday = day 0). */
function mealPlanDate(weekStart: string, dayOfWeek: number): string {
  const [y, m, d] = weekStart.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + dayOfWeek);
  return toISO(date);
}

/** Last N Mondays, most-recent first. */
function lastNMondays(n: number): string[] {
  const result: string[] = [];
  const d = new Date();
  const day = d.getDay();
  d.setDate(d.getDate() - (day === 0 ? 6 : day - 1));
  d.setHours(0, 0, 0, 0);
  for (let i = 0; i < n; i++) {
    result.push(toISO(new Date(d)));
    d.setDate(d.getDate() - 7);
  }
  return result;
}

/** True if the tier should break a FODMAP streak. */
function isBad(tier: string | null | undefined): boolean {
  return tier === 'moderate' || tier === 'high';
}

// ── Hook ──────────────────────────────────────────────────────────

export function useFodmapStreak() {
  const [streak, setStreak] = useState(0);

  const fetchStreak = useCallback(async () => {
    const today = toISO(new Date());
    const weekStarts = lastNMondays(16);

    // ── Step 1: meal_plans → recipe_ids per date ─────────────────
    const { data: plans } = await supabase
      .from('meal_plans')
      .select('week_start, day_of_week, recipe_id')
      .in('week_start', weekStarts)
      .not('recipe_id', 'is', null);

    type PlanRow = { week_start: string; day_of_week: number; recipe_id: string };
    type IngRow  = { recipe_id: string; fodmap_tier: string | null; ingredients: { fodmap_tier: string } | null };
    type LogRow  = { id: string; date: string; meal_log_ingredients: { fodmap_tier: string | null }[] };

    const recipeIds = [
      ...new Set((plans ?? []).map((p: PlanRow) => p.recipe_id)),
    ];

    // ── Step 2: ingredient tiers per recipe ──────────────────────
    // Use fodmap_ingredients.tier when linked, otherwise recipe_ingredients.fodmap_tier
    const recipeTiersMap = new Map<string, string[]>(); // recipe_id → tiers

    if (recipeIds.length > 0) {
      const { data: ings } = await supabase
        .from('recipe_ingredients')
        .select('recipe_id, fodmap_tier, ingredients(fodmap_tier)')
        .in('recipe_id', recipeIds);

      for (const ing of (ings ?? []) as unknown as IngRow[]) {
        const tier: string =
          ing.ingredients?.fodmap_tier ?? ing.fodmap_tier ?? 'unknown';
        const list = recipeTiersMap.get(ing.recipe_id) ?? [];
        list.push(tier);
        recipeTiersMap.set(ing.recipe_id, list);
      }
    }

    // ── Step 3: aggregate tiers per calendar date (from plans) ───
    const planTiersByDate = new Map<string, string[]>();

    for (const plan of (plans ?? []) as PlanRow[]) {
      const date = mealPlanDate(plan.week_start, plan.day_of_week);
      if (date > today) continue;
      const tiers = recipeTiersMap.get(plan.recipe_id) ?? [];
      const existing = planTiersByDate.get(date) ?? [];
      planTiersByDate.set(date, [...existing, ...tiers]);
    }

    // ── Step 4: meal_logs + their ingredients ────────────────────
    const oldestDate = (() => {
      const d = new Date();
      d.setDate(d.getDate() - 16 * 7);
      return toISO(d);
    })();

    const { data: logs } = await supabase
      .from('meal_logs')
      .select('id, date, meal_log_ingredients(fodmap_tier)')
      .gte('date', oldestDate)
      .lte('date', today);

    // ── Step 5: aggregate log tiers per date ─────────────────────
    const logTiersByDate = new Map<string, string[]>();

    for (const log of (logs ?? []) as LogRow[]) {
      const tiers = (log.meal_log_ingredients ?? []).map(
        (i) => i.fodmap_tier ?? 'unknown'
      );
      if (tiers.length === 0) continue; // log with no ingredients → ignore
      const existing = logTiersByDate.get(log.date) ?? [];
      logTiersByDate.set(log.date, [...existing, ...tiers]);
    }

    // ── Step 6: decide if a day is FODMAP-safe ───────────────────
    const isSafeDay = (date: string): boolean => {
      // Prefer actual log if it has ingredients
      const logTiers = logTiersByDate.get(date);
      if (logTiers && logTiers.length > 0) {
        return !logTiers.some(isBad);
      }

      // Fall back to planned recipe ingredients
      const planTiers = planTiersByDate.get(date);
      if (planTiers && planTiers.length > 0) {
        return !planTiers.some(isBad);
      }

      // No data → not a FODMAP day
      return false;
    };

    // ── Step 7: count consecutive days from today ────────────────
    let count = 0;
    const cursor = new Date();

    while (isSafeDay(toISO(cursor))) {
      count++;
      cursor.setDate(cursor.getDate() - 1);
    }

    setStreak(count);
  }, []);

  return { streak, fetchStreak };
}
