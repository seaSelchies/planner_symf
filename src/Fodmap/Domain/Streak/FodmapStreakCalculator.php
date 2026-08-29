<?php

namespace App\Fodmap\Domain\Streak;

use App\Fodmap\Domain\Tier\FodmapTier;

final class FodmapStreakCalculator
{
    /**
     * @param array<string, FodmapTier[]> $loggedTiersByDate
     * @param array<string, FodmapTier[]> $plannedTiersByDate
     */
    public function streak(
        array $loggedTiersByDate,
        array $plannedTiersByDate,
        \DateTimeImmutable $today,
    ): int {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
