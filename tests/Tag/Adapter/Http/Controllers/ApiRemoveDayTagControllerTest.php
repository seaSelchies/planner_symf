<?php

namespace App\Tests\Tag\Adapter\Http\Controllers;

use App\Tag\Adapter\Http\Controllers\ApiRemoveDayTagController;
use App\Tag\Domain\DayTagDataFetchException;
use App\Tag\Domain\DayTagNotFoundException;
use PHPUnit\Framework\TestCase;

/**
 * Covers the controller half of the command's happy path (invariant 28 — empty-bodied 200, not
 * a numbered Case id) and the Adapter half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md), per the status codes the /contract proposal
 * declared for this endpoint (200 / 404 / 503).
 */
final class ApiRemoveDayTagControllerTest extends TestCase
{
    public function testSuccessReturnsAnEmptyBodied200(): void
    {
        $controller = new ApiRemoveDayTagController(new FakeCommandBus());

        $response = $controller('2026-08-31', 'alcohol');

        self::assertSame(200, $response->getStatusCode());
        self::assertNull(json_decode($response->getContent(), true));
    }

    public function testNotFoundMapsTo404(): void
    {
        $controller = new ApiRemoveDayTagController(
            new FakeCommandBus(throws: new DayTagNotFoundException('not found')),
        );

        $response = $controller('2026-08-31', 'alcohol');

        self::assertSame(404, $response->getStatusCode());
        self::assertSame(['error' => 'not found'], json_decode($response->getContent(), true));
    }

    public function testFetchFailureMapsTo503(): void
    {
        $controller = new ApiRemoveDayTagController(
            new FakeCommandBus(throws: new DayTagDataFetchException('fetch failed')),
        );

        $response = $controller('2026-08-31', 'alcohol');

        self::assertSame(503, $response->getStatusCode());
        self::assertSame(['error' => 'fetch failed'], json_decode($response->getContent(), true));
    }
}
