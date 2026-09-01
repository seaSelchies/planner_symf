<?php

namespace App\Tests\Tag\Application\Command\ToggleDayTag;

use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagProvider;

final class InMemoryDayTagProvider implements DayTagProvider
{
    private bool $findWasCalled = false;
    private ?string $findReceivedUserId = null;
    private ?string $findReceivedDate = null;
    private ?string $findReceivedTag = null;

    public function __construct(
        private readonly ?DayTag $findResult = null,
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function tagsForDates(string $userId, array $dates): array
    {
        return [];
    }

    public function findByUserDateTag(string $userId, string $date, string $tag): ?DayTag
    {
        $this->findWasCalled = true;
        $this->findReceivedUserId = $userId;
        $this->findReceivedDate = $date;
        $this->findReceivedTag = $tag;

        if ($this->throws !== null) {
            throw $this->throws;
        }

        return $this->findResult;
    }

    public function findWasCalled(): bool
    {
        return $this->findWasCalled;
    }

    public function findReceivedUserId(): ?string
    {
        return $this->findReceivedUserId;
    }

    public function findReceivedDate(): ?string
    {
        return $this->findReceivedDate;
    }

    public function findReceivedTag(): ?string
    {
        return $this->findReceivedTag;
    }
}
