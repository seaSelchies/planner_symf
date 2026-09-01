<?php

namespace App\Tag\Domain;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'day_tags')]
#[ORM\UniqueConstraint(name: 'day_tags_user_date_tag', columns: ['user_id', 'date', 'tag'])]
class DayTag
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    #[ORM\Column(name: 'user_id', type: 'guid')]
    private string $userId;

    #[ORM\Column(type: 'date')]
    private \DateTimeInterface $date;

    #[ORM\Column(type: 'text')]
    private string $tag;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $notes = null;

    // The live table's created_at is a plain `timestamptz` (no explicit precision, so Postgres
    // keeps microseconds) — the stock 'datetimetz_immutable' type only parses "Y-m-d H:i:sO",
    // no fraction, and fails reading it back. 'datetimetz_immutable_microseconds' is a custom
    // type (App\Tag\Infrastructure\DB\DateTimeTzImmutableMicrosecondsType) that tolerates both
    // the fractional seconds and Postgres's 2-digit UTC offset.
    #[ORM\Column(name: 'created_at', type: 'datetimetz_immutable_microseconds', options: ['precision' => 6])]
    private \DateTimeImmutable $createdAt;

    public function __construct(
        string $id,
        string $userId,
        \DateTimeInterface $date,
        string $tag,
        ?string $notes,
        \DateTimeImmutable $createdAt,
    ) {
        $this->id = $id;
        $this->userId = $userId;
        $this->date = $date;
        $this->tag = $tag;
        $this->notes = $notes;
        $this->createdAt = $createdAt;
    }

    public function id(): string
    {
        return $this->id;
    }

    public function userId(): string
    {
        return $this->userId;
    }

    public function date(): \DateTimeInterface
    {
        return $this->date;
    }

    public function tag(): string
    {
        return $this->tag;
    }

    public function notes(): ?string
    {
        return $this->notes;
    }

    public function createdAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }
}
