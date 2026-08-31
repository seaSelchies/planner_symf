<?php

namespace App\Tests\Fodmap\Application\Query\GetFodmapStreak;

use App\Fodmap\Domain\MealLog\LoggedTierProvider;

final class InMemoryLoggedTierProvider implements LoggedTierProvider
{
    private ?string $receivedUserId = null;
    private ?\DateTimeImmutable $receivedToday = null;

    public function __construct(
        private readonly array $tiersByDate = [],
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function loggedTiersByDate(string $userId, \DateTimeImmutable $today): array
    {
        $this->receivedUserId = $userId;
        $this->receivedToday = $today;

        if ($this->throws !== null) {
            throw $this->throws;
        }

        return $this->tiersByDate;
    }

    public function receivedUserId(): ?string
    {
        return $this->receivedUserId;
    }

    public function receivedToday(): ?\DateTimeImmutable
    {
        return $this->receivedToday;
    }
}
