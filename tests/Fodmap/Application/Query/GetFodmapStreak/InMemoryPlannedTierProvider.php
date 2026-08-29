<?php

namespace App\Tests\Fodmap\Application\Query\GetFodmapStreak;

use App\Fodmap\Domain\MealPlan\PlannedTierProvider;

final class InMemoryPlannedTierProvider implements PlannedTierProvider
{
    private ?\DateTimeImmutable $receivedToday = null;

    public function __construct(
        private readonly array $tiersByDate = [],
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function plannedTiersByDate(\DateTimeImmutable $today): array
    {
        $this->receivedToday = $today;

        if ($this->throws !== null) {
            throw $this->throws;
        }

        return $this->tiersByDate;
    }

    public function receivedToday(): ?\DateTimeImmutable
    {
        return $this->receivedToday;
    }
}
