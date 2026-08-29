<?php

namespace App\Tests\Fodmap\Application\Query\GetFodmapStreak;

use App\Fodmap\Domain\MealLog\LoggedTierProvider;

final class InMemoryLoggedTierProvider implements LoggedTierProvider
{
    private ?\DateTimeImmutable $receivedToday = null;

    public function __construct(
        private readonly array $tiersByDate = [],
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function loggedTiersByDate(\DateTimeImmutable $today): array
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
