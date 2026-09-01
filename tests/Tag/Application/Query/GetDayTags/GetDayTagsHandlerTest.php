<?php

namespace App\Tests\Tag\Application\Query\GetDayTags;

use App\Tag\Application\Query\GetDayTags\GetDayTagsHandler;
use App\Tag\Application\Query\GetDayTags\GetDayTagsQuery;
use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagDataFetchException;
use PHPUnit\Framework\TestCase;

/**
 * Covers C1 and C2 (docs/specs/use-day-tags.md) and the read half of
 * T:day-tags-write-failure-signalling (docs/todo/day-tags-write-failure-signalling.md) and the
 * Application-layer half of T:day-tags-user-scoping (docs/todo/day-tags-user-scoping.md) — the
 * handler must pass the query's userId through to the provider unchanged. See
 * tests/Tag/CASE-COVERAGE.md for the full accounting, including cases this handler cannot cover.
 */
final class GetDayTagsHandlerTest extends TestCase
{
    public function testC2DataReturnedByTheProviderIsIncludedInTheResponse(): void
    {
        $dayTag = new DayTag(
            id: 't1',
            userId: 'user-1',
            date: new \DateTimeImmutable('2026-08-31'),
            tag: 'alcohol',
            notes: null,
            createdAt: new \DateTimeImmutable('2026-08-31T10:00:00+00:00'),
        );
        $provider = new InMemoryDayTagProvider(dayTags: [$dayTag]);
        $handler = new GetDayTagsHandler($provider);

        $response = $handler(new GetDayTagsQuery('user-1', ['2026-08-31']));

        self::assertSame([$dayTag], $response->dayTags);
    }

    public function testC1EmptyDatesReturnsEmptyListAndUserIdIsPassedThrough(): void
    {
        $provider = new InMemoryDayTagProvider();
        $handler = new GetDayTagsHandler($provider);

        $response = $handler(new GetDayTagsQuery('user-1', []));

        self::assertSame([], $response->dayTags);
        self::assertSame('user-1', $provider->tagsForDatesReceivedUserId());
        self::assertSame([], $provider->tagsForDatesReceivedDates());
    }

    public function testDatesArePassedThroughToTheProviderUnchanged(): void
    {
        $provider = new InMemoryDayTagProvider();
        $handler = new GetDayTagsHandler($provider);

        $handler(new GetDayTagsQuery('user-1', ['2026-08-31', '2026-09-01']));

        self::assertSame(['2026-08-31', '2026-09-01'], $provider->tagsForDatesReceivedDates());
    }

    public function testFetchFailurePropagatesUncaught(): void
    {
        $provider = new InMemoryDayTagProvider(throws: new DayTagDataFetchException('fetch failed'));
        $handler = new GetDayTagsHandler($provider);

        try {
            $handler(new GetDayTagsQuery('user-1', ['2026-08-31']));
            self::fail('Expected DayTagDataFetchException to propagate uncaught.');
        } catch (DayTagDataFetchException $e) {
            self::assertSame('fetch failed', $e->getMessage());
        }
    }
}
