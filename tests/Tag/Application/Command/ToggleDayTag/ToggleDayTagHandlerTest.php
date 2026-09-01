<?php

namespace App\Tests\Tag\Application\Command\ToggleDayTag;

use App\Tag\Application\Command\ToggleDayTag\ToggleDayTagCommand;
use App\Tag\Application\Command\ToggleDayTag\ToggleDayTagHandler;
use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagAlreadyExistsException;
use App\Tag\Domain\DayTagDataFetchException;
use PHPUnit\Framework\TestCase;

/**
 * Covers C6 and C8 (docs/specs/use-day-tags.md) and the write half of
 * T:day-tags-write-failure-signalling (docs/todo/day-tags-write-failure-signalling.md) and the
 * Application-layer half of T:day-tags-user-scoping (docs/todo/day-tags-user-scoping.md).
 */
final class ToggleDayTagHandlerTest extends TestCase
{
    public function testC6MatchingRowDeletesItAndNeverCreates(): void
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
        $handler = new ToggleDayTagHandler($provider, $repository);

        $handler(new ToggleDayTagCommand('user-1', '2026-08-31', 'alcohol'));

        self::assertSame([['userId' => 'user-1', 'id' => 't1']], $repository->deleteCalls());
        self::assertSame([], $repository->createCalls());
    }

    public function testC8NoMatchingRowCreatesOneWithNoNotes(): void
    {
        $provider = new InMemoryDayTagProvider(findResult: null);
        $repository = new InMemoryDayTagRepository();
        $handler = new ToggleDayTagHandler($provider, $repository);

        $handler(new ToggleDayTagCommand('user-1', '2026-08-31', 'workout'));

        self::assertSame('user-1', $provider->findReceivedUserId());
        self::assertSame('2026-08-31', $provider->findReceivedDate());
        self::assertSame('workout', $provider->findReceivedTag());
        self::assertSame(
            [['userId' => 'user-1', 'date' => '2026-08-31', 'tag' => 'workout', 'notes' => null]],
            $repository->createCalls(),
        );
        self::assertSame([], $repository->deleteCalls());
    }

    public function testFindFailurePropagatesUncaught(): void
    {
        $provider = new InMemoryDayTagProvider(throws: new DayTagDataFetchException('find failed'));
        $handler = new ToggleDayTagHandler($provider, new InMemoryDayTagRepository());

        try {
            $handler(new ToggleDayTagCommand('user-1', '2026-08-31', 'workout'));
            self::fail('Expected DayTagDataFetchException to propagate uncaught.');
        } catch (DayTagDataFetchException $e) {
            self::assertSame('find failed', $e->getMessage());
        }
    }

    public function testC9CreateFailurePropagatesUncaught(): void
    {
        $repository = new InMemoryDayTagRepository(
            throwsOnCreate: new DayTagAlreadyExistsException('already exists'),
        );
        $handler = new ToggleDayTagHandler(new InMemoryDayTagProvider(findResult: null), $repository);

        try {
            $handler(new ToggleDayTagCommand('user-1', '2026-08-31', 'workout'));
            self::fail('Expected DayTagAlreadyExistsException to propagate uncaught.');
        } catch (DayTagAlreadyExistsException $e) {
            self::assertSame('already exists', $e->getMessage());
        }
    }
}
