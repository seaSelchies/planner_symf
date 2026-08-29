<?php

namespace App\Fodmap\Domain\MealPlan;

final class MealPlanDate
{
    public function resolve(\DateTimeImmutable $weekStart, int $dayOfWeek): \DateTimeImmutable
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
