<?php

namespace App\Fodmap\Domain\MealPlan;

use App\Fodmap\Domain\Tier\FodmapTier;

final class IngredientTierPrecedence
{
    public function resolve(?FodmapTier $catalogueTier, ?FodmapTier $recipeTier): FodmapTier
    {
        return $catalogueTier ?? $recipeTier ?? FodmapTier::Unknown;
    }
}
