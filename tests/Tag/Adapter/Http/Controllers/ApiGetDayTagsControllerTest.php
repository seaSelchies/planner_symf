<?php

namespace App\Tests\Tag\Adapter\Http\Controllers;

use App\Tag\Adapter\Http\Controllers\ApiGetDayTagsController;
use App\Tag\Application\Query\GetDayTags\GetDayTagsResponse;
use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagDataFetchException;
use PHPUnit\Framework\TestCase;
use Symfony\Component\HttpFoundation\Request;

/**
 * Covers the controller half of the query's happy path (invariants 28, 30 — not a numbered
 * Case id) and the Adapter half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md): a fetch failure must map to a 503 response
 * with the Domain exception's message, per invariant 29.
 *
 * The exact JSON field names for a `DayTag` (id/date/tag/notes/createdAt, `userId` omitted as
 * redundant with the authenticated caller) are this test's own assumption, not something
 * `/contract`'s declarations fix — noted here since nothing else records it.
 */
final class ApiGetDayTagsControllerTest extends TestCase
{
    public function testReturnsAnEmptyListAsJson(): void
    {
        $controller = new ApiGetDayTagsController(
            new FakeQueryBus(response: new GetDayTagsResponse(dayTags: [])),
        );

        $response = $controller(Request::create('/api/tags', 'GET', ['dates' => ['2026-08-31']]));

        self::assertSame(200, $response->getStatusCode());
        self::assertSame(['dayTags' => []], json_decode($response->getContent(), true));
    }

    public function testReturnsAPopulatedListAsJson(): void
    {
        $dayTag = new DayTag(
            id: 't1',
            userId: 'user-1',
            date: new \DateTimeImmutable('2026-08-31'),
            tag: 'alcohol',
            notes: 'one glass',
            createdAt: new \DateTimeImmutable('2026-08-31T10:00:00+00:00'),
        );
        $controller = new ApiGetDayTagsController(
            new FakeQueryBus(response: new GetDayTagsResponse(dayTags: [$dayTag])),
        );

        $response = $controller(Request::create('/api/tags', 'GET', ['dates' => ['2026-08-31']]));

        self::assertSame(200, $response->getStatusCode());
        self::assertSame(
            ['dayTags' => [[
                'id' => 't1',
                'date' => '2026-08-31',
                'tag' => 'alcohol',
                'notes' => 'one glass',
                'createdAt' => '2026-08-31T10:00:00+00:00',
            ]]],
            json_decode($response->getContent(), true),
        );
    }

    public function testFetchFailureMapsToA503Response(): void
    {
        $controller = new ApiGetDayTagsController(
            new FakeQueryBus(throws: new DayTagDataFetchException('fetch failed')),
        );

        $response = $controller(Request::create('/api/tags', 'GET', ['dates' => ['2026-08-31']]));

        self::assertSame(503, $response->getStatusCode());
        self::assertSame(['error' => 'fetch failed'], json_decode($response->getContent(), true));
    }
}
