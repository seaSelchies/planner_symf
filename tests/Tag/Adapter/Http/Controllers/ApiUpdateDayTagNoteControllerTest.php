<?php

namespace App\Tests\Tag\Adapter\Http\Controllers;

use App\Tag\Adapter\Http\Controllers\ApiUpdateDayTagNoteController;
use App\Tag\Domain\DayTagNotFoundException;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

/**
 * Covers the controller half of the command's happy path (invariant 28 — empty-bodied 200, not
 * a numbered Case id) and the Adapter half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md), per the status codes the /contract proposal
 * declared for this endpoint (200 / 404 only).
 */
final class ApiUpdateDayTagNoteControllerTest extends TestCase
{
    private function request(): Request
    {
        return Request::create('/api/tags/tag-1', 'PATCH', content: json_encode(['notes' => 'note']));
    }

    public function testSuccessReturnsAnEmptyBodied200(): void
    {
        $controller = new ApiUpdateDayTagNoteController(new FakeCommandBus());

        $response = $controller('tag-1', $this->request());

        self::assertSame(200, $response->getStatusCode());
        self::assertNull(json_decode($response->getContent(), true));
    }

    public function testNotFoundMapsTo404(): void
    {
        $controller = new ApiUpdateDayTagNoteController(
            new FakeCommandBus(throws: new DayTagNotFoundException('not found')),
        );

        $response = $controller('tag-1', $this->request());

        self::assertSame(404, $response->getStatusCode());
        self::assertSame(['error' => 'not found'], json_decode($response->getContent(), true));
    }
}
