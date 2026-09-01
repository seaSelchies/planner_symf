<?php

namespace App\Tests\Tag\Adapter\Http\Controllers;

use App\Tag\Adapter\Http\Controllers\ApiToggleDayTagController;
use App\Tag\Domain\DayTagAlreadyExistsException;
use App\Tag\Domain\DayTagDataFetchException;
use App\Tag\Domain\DayTagNotFoundException;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

/**
 * Covers the controller half of the command's happy path (invariant 28 — empty-bodied 200, not
 * a numbered Case id) and the Adapter half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md): the three exceptions this command can throw
 * each map to the status code the /contract proposal declared.
 */
final class ApiToggleDayTagControllerTest extends TestCase
{
    private function request(): Request
    {
        return Request::create(
            '/api/tags/toggle',
            'POST',
            content: json_encode(['date' => '2026-08-31', 'tag' => 'alcohol']),
        );
    }

    public function testSuccessReturnsAnEmptyBodied200(): void
    {
        $controller = new ApiToggleDayTagController(new FakeCommandBus());

        $response = $controller($this->request());

        self::assertSame(200, $response->getStatusCode());
        self::assertNull(json_decode($response->getContent(), true));
    }

    public function testAlreadyExistsMapsTo409(): void
    {
        $controller = new ApiToggleDayTagController(
            new FakeCommandBus(throws: new DayTagAlreadyExistsException('already exists')),
        );

        $response = $controller($this->request());

        self::assertSame(409, $response->getStatusCode());
        self::assertSame(['error' => 'already exists'], json_decode($response->getContent(), true));
    }

    public function testNotFoundMapsTo404(): void
    {
        $controller = new ApiToggleDayTagController(
            new FakeCommandBus(throws: new DayTagNotFoundException('not found')),
        );

        $response = $controller($this->request());

        self::assertSame(404, $response->getStatusCode());
        self::assertSame(['error' => 'not found'], json_decode($response->getContent(), true));
    }

    public function testFetchFailureMapsTo503(): void
    {
        $controller = new ApiToggleDayTagController(
            new FakeCommandBus(throws: new DayTagDataFetchException('fetch failed')),
        );

        $response = $controller($this->request());

        self::assertSame(503, $response->getStatusCode());
        self::assertSame(['error' => 'fetch failed'], json_decode($response->getContent(), true));
    }
}
