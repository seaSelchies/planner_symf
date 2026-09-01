<?php

namespace App\Tests\Tag\Adapter\Http\Controllers;

use App\Tag\Adapter\Http\Controllers\ApiUpsertDayTagController;
use App\Tag\Domain\DayTagAlreadyExistsException;
use App\Tag\Domain\DayTagDataFetchException;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

/**
 * Covers the controller half of the command's happy path (invariant 28 — empty-bodied 200, not
 * a numbered Case id) and the Adapter half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md), per the status codes the /contract proposal
 * declared for this endpoint (200 / 409 / 503 — no 404, unlike Toggle/Remove).
 */
final class ApiUpsertDayTagControllerTest extends TestCase
{
    private function request(): Request
    {
        return Request::create(
            '/api/tags',
            'PUT',
            content: json_encode(['date' => '2026-08-31', 'tag' => 'toilet', 'notes' => 'note']),
        );
    }

    public function testSuccessReturnsAnEmptyBodied200(): void
    {
        $controller = new ApiUpsertDayTagController(new FakeCommandBus());

        $response = $controller($this->request());

        self::assertSame(200, $response->getStatusCode());
        self::assertNull(json_decode($response->getContent(), true));
    }

    public function testAlreadyExistsMapsTo409(): void
    {
        $controller = new ApiUpsertDayTagController(
            new FakeCommandBus(throws: new DayTagAlreadyExistsException('already exists')),
        );

        $response = $controller($this->request());

        self::assertSame(409, $response->getStatusCode());
        self::assertSame(['error' => 'already exists'], json_decode($response->getContent(), true));
    }

    public function testFetchFailureMapsTo503(): void
    {
        $controller = new ApiUpsertDayTagController(
            new FakeCommandBus(throws: new DayTagDataFetchException('fetch failed')),
        );

        $response = $controller($this->request());

        self::assertSame(503, $response->getStatusCode());
        self::assertSame(['error' => 'fetch failed'], json_decode($response->getContent(), true));
    }
}
