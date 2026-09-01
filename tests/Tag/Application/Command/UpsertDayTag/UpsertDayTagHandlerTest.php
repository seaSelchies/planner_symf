<?php

namespace App\Tests\Tag\Application\Command\UpsertDayTag;

use App\Tag\Application\Command\UpsertDayTag\UpsertDayTagCommand;
use App\Tag\Application\Command\UpsertDayTag\UpsertDayTagHandler;
use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagAlreadyExistsException;
use App\Tag\Domain\DayTagDataFetchException;
use PHPUnit\Framework\TestCase;

/**
 * Covers both branches of `upsertTag` (docs/specs/use-day-tags.md's Contract "Rule"
 * paragraph — C13-C15 are corrupted on disk and not usable as a source, see
 * tests/Tag/CASE-COVERAGE.md), the write half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md), and the Application-layer half of
 * T:day-tags-user-scoping (docs/todo/day-tags-user-scoping.md). It also demonstrates the
 * /contract "normalize" decision: notes are stored exactly as given, including an empty
 * string, with no `'' -> null` coercion.
 */
final class UpsertDayTagHandlerTest extends TestCase
{
    public function testExistingRowDelegatesToUpdatingItsNotesAndNeverCreates(): void
    {
        $existing = new DayTag(
            id: 't3',
            userId: 'user-1',
            date: new \DateTimeImmutable('2026-08-31'),
            tag: 'toilet',
            notes: null,
            createdAt: new \DateTimeImmutable('2026-08-31T10:00:00+00:00'),
        );
        $provider = new InMemoryDayTagProvider(findResult: $existing);
        $repository = new InMemoryDayTagRepository();
        $handler = new UpsertDayTagHandler($provider, $repository);

        $handler(new UpsertDayTagCommand('user-1', '2026-08-31', 'toilet', 'note text'));

        self::assertSame(
            [['userId' => 'user-1', 'id' => 't3', 'notes' => 'note text']],
            $repository->updateNotesCalls(),
        );
        self::assertSame([], $repository->createCalls());
    }

    public function testNoExistingRowCreatesOneWithNotesStoredExactlyAsGiven(): void
    {
        $provider = new InMemoryDayTagProvider(findResult: null);
        $repository = new InMemoryDayTagRepository();
        $handler = new UpsertDayTagHandler($provider, $repository);

        $handler(new UpsertDayTagCommand('user-1', '2026-08-31', 'toilet', ''));

        self::assertSame('user-1', $provider->findReceivedUserId());
        self::assertSame('2026-08-31', $provider->findReceivedDate());
        self::assertSame('toilet', $provider->findReceivedTag());
        self::assertSame(
            [['userId' => 'user-1', 'date' => '2026-08-31', 'tag' => 'toilet', 'notes' => '']],
            $repository->createCalls(),
        );
        self::assertSame([], $repository->updateNotesCalls());
    }

    public function testFindFailurePropagatesUncaught(): void
    {
        $provider = new InMemoryDayTagProvider(throws: new DayTagDataFetchException('find failed'));
        $handler = new UpsertDayTagHandler($provider, new InMemoryDayTagRepository());

        try {
            $handler(new UpsertDayTagCommand('user-1', '2026-08-31', 'toilet', null));
            self::fail('Expected DayTagDataFetchException to propagate uncaught.');
        } catch (DayTagDataFetchException $e) {
            self::assertSame('find failed', $e->getMessage());
        }
    }

    public function testCreateFailurePropagatesUncaught(): void
    {
        $repository = new InMemoryDayTagRepository(
            throwsOnCreate: new DayTagAlreadyExistsException('already exists'),
        );
        $handler = new UpsertDayTagHandler(new InMemoryDayTagProvider(findResult: null), $repository);

        try {
            $handler(new UpsertDayTagCommand('user-1', '2026-08-31', 'toilet', null));
            self::fail('Expected DayTagAlreadyExistsException to propagate uncaught.');
        } catch (DayTagAlreadyExistsException $e) {
            self::assertSame('already exists', $e->getMessage());
        }
    }
}
