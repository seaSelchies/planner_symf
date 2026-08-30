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
        $streak = 0;
        $cursor = $today;
        $tiers = $this->tiersFor($cursor, $loggedTiersByDate, $plannedTiersByDate);

        while ($tiers !== null && $tiers !== [] && !$this->anyBad($tiers)) {
            $streak++;
            $cursor = $cursor->modify('-1 day');
            $tiers = $this->tiersFor($cursor, $loggedTiersByDate, $plannedTiersByDate);
        }

        return $streak;
    }

    /**
     * @param array<string, FodmapTier[]> $loggedTiersByDate
     * @param array<string, FodmapTier[]> $plannedTiersByDate
     * @return FodmapTier[]|null null when the date has no data in either map
     */
    private function tiersFor(
        \DateTimeImmutable $date,
        array $loggedTiersByDate,
        array $plannedTiersByDate,
    ): ?array {
        $dateKey = $date->format('Y-m-d');

        if (array_key_exists($dateKey, $loggedTiersByDate)) {
            return $loggedTiersByDate[$dateKey];
        }

        if (array_key_exists($dateKey, $plannedTiersByDate)) {
            return $plannedTiersByDate[$dateKey];
        }

        return null;
    }

    /**
     * @param FodmapTier[] $tiers
     */
    private function anyBad(array $tiers): bool
    {
        foreach ($tiers as $tier) {
            if ($tier->isBad()) {
                return true;
            }
        }

        return false;
    }
}
