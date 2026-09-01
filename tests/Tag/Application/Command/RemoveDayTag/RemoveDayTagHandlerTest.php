<?php

namespace App\Tests\Tag\Application\Command\RemoveDayTag;

use App\Tag\Application\Command\RemoveDayTag\RemoveDayTagCommand;
use App\Tag\Application\Command\RemoveDayTag\RemoveDayTagHandler;
use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagDataFetchException;
use App\Tag\Domain\DayTagNotFoundException;
use PHPUnit\Framework\TestCase;

/**
 * Covers C16 as superseded by /contract's failure-signalling divergence — no match now throws
 * `DayTagNotFoundException` instead of silently no-op'ing (docs/specs/use-day-tags.md;
 * docs/todo/day-tags-write-failure-signalling.md) — and C17, and the Application-layer half of
 * T:day-tags-user-scoping (docs/todo/day-tags-user-scoping.md).
 */
final class RemoveDayTagHandlerTest extends TestCase
{
    public function testC17MatchingRowDeletesIt(): void
    {
        $existing = new DayTag(
            id: 't1',
            userId: 'user-1',
            date: new \DateTimeImmutable('2026-08-31'),
            tag: 'alcohol',
            notes: null,
            createdAt: new \DateTimeImmutable('2026-08-31T10:00:00+00:00'),
        );
        $provider = new InMemoryDayTagProvider(findResult: $existing);
        $repository = new InMemoryDayTagRepository();
        $handler = new RemoveDayTagHandler($provider, $repository);

        $handler(new RemoveDayTagCommand('user-1', '2026-08-31', 'alcohol'));

        self::assertSame([['userId' => 'user-1', 'id' => 't1']], $repository->deleteCalls());
    }

    public function testC16NoMatchingRowThrowsNotFoundAndNeverDeletes(): void
    {
        $provider = new InMemoryDayTagProvider(findResult: null);
        $repository = new InMemoryDayTagRepository();
        $handler = new RemoveDayTagHandler($provider, $repository);

        try {
            $handler(new RemoveDayTagCommand('user-1', '2026-08-31', 'alcohol'));
            self::fail('Expected DayTagNotFoundException to be thrown.');
        } catch (DayTagNotFoundException) {
            self::assertSame('user-1', $provider->findReceivedUserId());
            self::assertSame('2026-08-31', $provider->findReceivedDate());
            self::assertSame('alcohol', $provider->findReceivedTag());
            self::assertSame([], $repository->deleteCalls());
        }
    }

    public function testFindFailurePropagatesUncaught(): void
    {
        $provider = new InMemoryDayTagProvider(throws: new DayTagDataFetchException('find failed'));
        $handler = new RemoveDayTagHandler($provider, new InMemoryDayTagRepository());

        try {
            $handler(new RemoveDayTagCommand('user-1', '2026-08-31', 'alcohol'));
            self::fail('Expected DayTagDataFetchException to propagate uncaught.');
        } catch (DayTagDataFetchException $e) {
            self::assertSame('find failed', $e->getMessage());
        }
    }
}
