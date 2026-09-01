<?php

namespace App\Tests\Tag\Application\Command\UpsertDayTag;

use App\Tag\Domain\DayTagRepository;

final class InMemoryDayTagRepository implements DayTagRepository
{
    /** @var array<int, array{userId: string, date: string, tag: string, notes: ?string}> */
    private array $createCalls = [];

    /** @var array<int, array{userId: string, id: string, notes: ?string}> */
    private array $updateNotesCalls = [];

    /** @var array<int, array{userId: string, id: string}> */
    private array $deleteCalls = [];

    public function __construct(
        private readonly ?\Throwable $throwsOnCreate = null,
        private readonly ?\Throwable $throwsOnUpdateNotes = null,
        private readonly ?\Throwable $throwsOnDelete = null,
    ) {
    }

    public function create(string $userId, string $date, string $tag, ?string $notes): void
    {
        $this->createCalls[] = ['userId' => $userId, 'date' => $date, 'tag' => $tag, 'notes' => $notes];

        if ($this->throwsOnCreate !== null) {
            throw $this->throwsOnCreate;
        }
    }

    public function updateNotes(string $userId, string $id, ?string $notes): void
    {
        $this->updateNotesCalls[] = ['userId' => $userId, 'id' => $id, 'notes' => $notes];

        if ($this->throwsOnUpdateNotes !== null) {
            throw $this->throwsOnUpdateNotes;
        }
    }

    public function delete(string $userId, string $id): void
    {
        $this->deleteCalls[] = ['userId' => $userId, 'id' => $id];

        if ($this->throwsOnDelete !== null) {
            throw $this->throwsOnDelete;
        }
    }

    public function createCalls(): array
    {
        return $this->createCalls;
    }

    public function updateNotesCalls(): array
    {
        return $this->updateNotesCalls;
    }

    public function deleteCalls(): array
    {
        return $this->deleteCalls;
    }
}
