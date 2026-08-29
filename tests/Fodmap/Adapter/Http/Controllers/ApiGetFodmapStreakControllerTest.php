<?php

namespace App\Tests\Fodmap\Adapter\Http\Controllers;

use App\Fodmap\Adapter\Http\Controllers\ApiGetFodmapStreakController;
use App\Fodmap\Application\Query\GetFodmapStreak\GetFodmapStreakResponse;
use App\Fodmap\Domain\FodmapDataFetchException;
use PHPUnit\Framework\TestCase;

/**
 * Covers the controller half of the query's happy path (invariants 28, 30 — no numbered Case id,
 * see tests/Fodmap/CASE-COVERAGE.md), and T:fodmap-streak-fetch-error-handling
 * (docs/todo/fodmap-streak-fetch-error-handling.md): a fetch failure must map to a 5xx response
 * with the Domain exception's message, per invariant 29 — never a silently reported 0 streak.
 */
final class ApiGetFodmapStreakControllerTest extends TestCase
{
    public function testReturnsTheStreakAsJson(): void
    {
        $controller = new ApiGetFodmapStreakController(
            new FakeQueryBus(response: new GetFodmapStreakResponse(streak: 4)),
        );

        $response = $controller();

        self::assertSame(200, $response->getStatusCode());
        self::assertSame(['streak' => 4], json_decode($response->getContent(), true));
    }

    public function testFetchFailureMapsToA5xxResponseNotAZeroStreak(): void
    {
        $controller = new ApiGetFodmapStreakController(
            new FakeQueryBus(throws: new FodmapDataFetchException('fetch failed')),
        );

        $response = $controller();

        self::assertGreaterThanOrEqual(500, $response->getStatusCode());
        self::assertLessThan(600, $response->getStatusCode());
        self::assertSame(['error' => 'fetch failed'], json_decode($response->getContent(), true));
    }
}
