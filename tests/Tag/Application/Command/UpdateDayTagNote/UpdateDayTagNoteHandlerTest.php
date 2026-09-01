<?php

namespace App\Tests\Tag\Application\Command\UpdateDayTagNote;

use App\Tag\Application\Command\UpdateDayTagNote\UpdateDayTagNoteCommand;
use App\Tag\Application\Command\UpdateDayTagNote\UpdateDayTagNoteHandler;
use App\Tag\Domain\DayTagNotFoundException;
use PHPUnit\Framework\TestCase;

/**
 * Covers C10 as superseded by /contract's "normalize" decision (docs/specs/use-day-tags.md;
 * see tests/Tag/CASE-COVERAGE.md for why the literal C10 — coercing '' to null — is not what
 * this handler does), the write half of T:day-tags-write-failure-signalling
 * (docs/todo/day-tags-write-failure-signalling.md), and the Application-layer half of
 * T:day-tags-user-scoping (docs/todo/day-tags-user-scoping.md).
 */
final class UpdateDayTagNoteHandlerTest extends TestCase
{
    public function testNotesAreStoredExactlyAsGivenIncludingEmptyString(): void
    {
        $repository = new InMemoryDayTagRepository();
        $handler = new UpdateDayTagNoteHandler($repository);

        $handler(new UpdateDayTagNoteCommand('user-1', 'tag-1', ''));

        self::assertSame(
            [['userId' => 'user-1', 'id' => 'tag-1', 'notes' => '']],
            $repository->updateNotesCalls(),
        );
    }

    public function testNotesNullIsStoredAsNull(): void
    {
        $repository = new InMemoryDayTagRepository();
        $handler = new UpdateDayTagNoteHandler($repository);

        $handler(new UpdateDayTagNoteCommand('user-1', 'tag-1', null));

        self::assertSame(
            [['userId' => 'user-1', 'id' => 'tag-1', 'notes' => null]],
            $repository->updateNotesCalls(),
        );
    }

    public function testNotFoundPropagatesUncaught(): void
    {
        $repository = new InMemoryDayTagRepository(
            throwsOnUpdateNotes: new DayTagNotFoundException('not found'),
        );
        $handler = new UpdateDayTagNoteHandler($repository);

        try {
            $handler(new UpdateDayTagNoteCommand('user-1', 'tag-1', 'note'));
            self::fail('Expected DayTagNotFoundException to propagate uncaught.');
        } catch (DayTagNotFoundException $e) {
            self::assertSame('not found', $e->getMessage());
        }
    }
}
