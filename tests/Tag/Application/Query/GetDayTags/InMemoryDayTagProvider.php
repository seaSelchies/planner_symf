<?php

namespace App\Tests\Tag\Application\Query\GetDayTags;

use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagProvider;

final class InMemoryDayTagProvider implements DayTagProvider
{
    private bool $tagsForDatesWasCalled = false;
    private ?string $tagsForDatesReceivedUserId = null;
    private ?array $tagsForDatesReceivedDates = null;

    public function __construct(
        private readonly array $dayTags = [],
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function tagsForDates(string $userId, array $dates): array
    {
        $this->tagsForDatesWasCalled = true;
        $this->tagsForDatesReceivedUserId = $userId;
        $this->tagsForDatesReceivedDates = $dates;

        if ($dates === []) {
            return [];
        }

        if ($this->throws !== null) {
            throw $this->throws;
        }

        return $this->dayTags;
    }

    public function findByUserDateTag(string $userId, string $date, string $tag): ?DayTag
    {
        return null;
    }

    public function tagsForDatesWasCalled(): bool
    {
        return $this->tagsForDatesWasCalled;
    }

    public function tagsForDatesReceivedUserId(): ?string
    {
        return $this->tagsForDatesReceivedUserId;
    }

    public function tagsForDatesReceivedDates(): ?array
    {
        return $this->tagsForDatesReceivedDates;
    }
}
