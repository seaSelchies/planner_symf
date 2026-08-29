<?php

namespace App\Tests\Fodmap\Application\Query\GetFodmapStreak;

use Symfony\Component\Clock\ClockInterface;

final class FakeClock implements ClockInterface
{
    public function __construct(
        private readonly \DateTimeImmutable $now,
    ) {
    }

    public function now(): \DateTimeImmutable
    {
        return $this->now;
    }

    public function sleep(int|float $seconds): void
    {
    }

    public function withTimeZone(\DateTimeZone|string $timezone): static
    {
        return $this;
    }
}
