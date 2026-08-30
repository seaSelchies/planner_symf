<?php

namespace App\Fodmap\Domain\MealPlan;

final class MealPlanDate
{
    public function resolve(\DateTimeImmutable $weekStart, int $dayOfWeek): \DateTimeImmutable
    {
        return $weekStart->modify(sprintf('%+d days', $dayOfWeek));
    }
}
