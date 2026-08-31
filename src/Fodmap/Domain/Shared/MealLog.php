<?php

namespace App\Fodmap\Domain\Shared;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'meal_logs')]
#[ORM\UniqueConstraint(name: 'meal_logs_user_date_type_unique', columns: ['user_id', 'date', 'meal_type'])]
class MealLog
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    #[ORM\Column(name: 'user_id', type: 'guid')]
    private string $userId;

    #[ORM\Column(type: 'date')]
    private \DateTimeInterface $date;

    #[ORM\Column(name: 'meal_type', type: 'text')]
    private string $mealType;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $notes = null;

    #[ORM\Column(name: 'created_at', type: 'datetimetz_immutable')]
    private \DateTimeImmutable $createdAt;

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

    public function mealType(): string
    {
        return $this->mealType;
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
