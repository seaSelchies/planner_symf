<?php

namespace App\Fodmap\Domain\MealPlan;

use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\Tier\FodmapTier;

interface PlannedTierProvider
{
    /**
     * @return array<string, FodmapTier[]> planned ingredient tiers keyed by ISO-8601 date
     *
     * @throws FodmapDataFetchException
     */
    public function plannedTiersByDate(\DateTimeImmutable $today): array;
}
