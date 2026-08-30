<?php

namespace App\Fodmap\Domain\MealPlan;

use App\Fodmap\Domain\Tier\FodmapTier;

final class IngredientTierPrecedence
{
    public function resolve(?FodmapTier $catalogueTier, ?FodmapTier $recipeTier): FodmapTier
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
