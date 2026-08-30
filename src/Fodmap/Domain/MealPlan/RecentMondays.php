<?php

namespace App\Fodmap\Domain\MealPlan;

final class RecentMondays
{
    /**
     * @return \DateTimeImmutable[] most-recent Monday first
     */
    public function lastN(\DateTimeImmutable $today, int $n): array
    {
        $dayOfWeek = (int) $today->format('N');
        $mostRecentMonday = $today->modify(sprintf('-%d days', $dayOfWeek - 1));

        $mondays = [];
        for ($i = 0; $i < $n; $i++) {
            $mondays[] = $mostRecentMonday->modify(sprintf('-%d days', $i * 7));
        }

        return $mondays;
    }
}
