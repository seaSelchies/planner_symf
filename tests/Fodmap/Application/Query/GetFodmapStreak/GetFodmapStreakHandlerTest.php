<?php

namespace App\Tests\Fodmap\Application\Query\GetFodmapStreak;

use App\Fodmap\Application\Query\GetFodmapStreak\GetFodmapStreakHandler;
use App\Fodmap\Application\Query\GetFodmapStreak\GetFodmapStreakQuery;
use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\Streak\FodmapStreakCalculator;
use PHPUnit\Framework\TestCase;

/**
 * Covers the "single clock read reused for the whole operation" requirement from the
 * specification's Hidden dependencies section (docs/specs/use-fodmap-streak.md) — not a numbered
 * Case id, see tests/Fodmap/CASE-COVERAGE.md — and T:fodmap-streak-fetch-error-handling: a provider's fetch failure must propagate
 * out of the handler uncaught, per .claude/rules/application-layer.md rule 2.
 *
 * Also covers the Application-layer half of T:fodmap-streak-user-scoping
 * (docs/todo/fodmap-streak-user-scoping.md): the handler must pass the query's userId through to
 * both providers unchanged. The Infrastructure-layer half (a real Postgres query actually scoped
 * to that user) is not covered here — see tests/Fodmap/CASE-COVERAGE.md.
 */
final class GetFodmapStreakHandlerTest extends TestCase
{
    public function testBothProvidersReceiveTheSameUserIdAndTheSameInstantFromASingleClockRead(): void
    {
        $today = new \DateTimeImmutable('2026-08-29');
        $plannedProvider = new InMemoryPlannedTierProvider();
        $loggedProvider = new InMemoryLoggedTierProvider();

        $handler = new GetFodmapStreakHandler(
            $plannedProvider,
            $loggedProvider,
            new FakeClock($today),
            new FodmapStreakCalculator(),
        );

        $handler(new GetFodmapStreakQuery('user-1'));

        self::assertSame('user-1', $plannedProvider->receivedUserId());
        self::assertSame('user-1', $loggedProvider->receivedUserId());
        self::assertEquals($today, $plannedProvider->receivedToday());
        self::assertEquals($today, $loggedProvider->receivedToday());
    }

    public function testFetchFailureFromPlannedProviderPropagatesUncaught(): void
    {
        $plannedProvider = new InMemoryPlannedTierProvider(
            throws: new FodmapDataFetchException('planned tier fetch failed'),
        );
        $handler = new GetFodmapStreakHandler(
            $plannedProvider,
            new InMemoryLoggedTierProvider(),
            new FakeClock(new \DateTimeImmutable('2026-08-29')),
            new FodmapStreakCalculator(),
        );

        try {
            $handler(new GetFodmapStreakQuery('user-1'));
            self::fail('Expected FodmapDataFetchException to propagate uncaught.');
        } catch (FodmapDataFetchException $e) {
            self::assertSame('planned tier fetch failed', $e->getMessage());
        }
    }

    public function testFetchFailureFromLoggedProviderPropagatesUncaught(): void
    {
        $loggedProvider = new InMemoryLoggedTierProvider(
            throws: new FodmapDataFetchException('logged tier fetch failed'),
        );
        $handler = new GetFodmapStreakHandler(
            new InMemoryPlannedTierProvider(),
            $loggedProvider,
            new FakeClock(new \DateTimeImmutable('2026-08-29')),
            new FodmapStreakCalculator(),
        );

        try {
            $handler(new GetFodmapStreakQuery('user-1'));
            self::fail('Expected FodmapDataFetchException to propagate uncaught.');
        } catch (FodmapDataFetchException $e) {
            self::assertSame('logged tier fetch failed', $e->getMessage());
        }
    }
}
