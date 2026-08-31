<?php

namespace App\Fodmap\Domain\MealLog;

use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\Tier\FodmapTier;

interface LoggedTierProvider
{
    /**
     * @return array<string, FodmapTier[]> logged ingredient tiers keyed by ISO-8601 date
     *
     * @throws FodmapDataFetchException
     */
    public function loggedTiersByDate(string $userId, \DateTimeImmutable $today): array;
}
