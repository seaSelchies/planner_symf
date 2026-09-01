<?php

namespace App\Tag\Infrastructure\DB;

use App\Tag\Domain\DayTagAlreadyExistsException;
use App\Tag\Domain\DayTagNotFoundException;
use App\Tag\Domain\DayTagRepository;
use Doctrine\DBAL\Exception\UniqueConstraintViolationException;
use Doctrine\ORM\EntityManagerInterface;

final class DoctrineDayTagRepository implements DayTagRepository
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
    ) {
    }

    // Inserted via the DBAL connection, not EntityManager::persist(): `id` and `created_at` are
    // left off the payload so Postgres applies its own defaults (gen_random_uuid(), now()) —
    // see docs/specs/use-day-tags-schema.md S6/S7 — rather than this class inventing a clock or
    // a UUID generator nobody agreed to inject (invariant 22, and /contract's shape for this
    // class carries neither collaborator).
    public function create(string $userId, string $date, string $tag, ?string $notes): void
    {
        try {
            $this->entityManager->getConnection()->insert('day_tags', [
                'user_id' => $userId,
                'date' => $date,
                'tag' => $tag,
                'notes' => $notes,
            ]);
        } catch (UniqueConstraintViolationException $e) {
            throw new DayTagAlreadyExistsException(sprintf(
                'A day tag already exists for user %s, date %s, tag %s.',
                $userId,
                $date,
                $tag,
            ), previous: $e);
        }
    }

    public function updateNotes(string $userId, string $id, ?string $notes): void
    {
        $affected = $this->entityManager->getConnection()->update(
            'day_tags',
            ['notes' => $notes],
            ['id' => $id, 'user_id' => $userId],
        );

        if ($affected === 0) {
            throw new DayTagNotFoundException(sprintf('No day tag %s found for user %s.', $id, $userId));
        }
    }

    public function delete(string $userId, string $id): void
    {
        $affected = $this->entityManager->getConnection()->delete(
            'day_tags',
            ['id' => $id, 'user_id' => $userId],
        );

        if ($affected === 0) {
            throw new DayTagNotFoundException(sprintf('No day tag %s found for user %s.', $id, $userId));
        }
    }
}
