<?php

namespace App\Fodmap\Domain\MealPlan;

final class RecentMondays
{
    /**
     * @return \DateTimeImmutable[] most-recent Monday first
     */
    public function lastN(\DateTimeImmutable $today, int $n): array
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
