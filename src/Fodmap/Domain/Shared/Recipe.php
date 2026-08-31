<?php

namespace App\Fodmap\Domain\Shared;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'recipes')]
class Recipe
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    #[ORM\Column(name: 'user_id', type: 'guid')]
    private string $userId;

    #[ORM\Column(type: 'text')]
    private string $name;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $description = null;

    #[ORM\Column(type: 'integer', options: ['default' => 2])]
    private int $servings = 2;

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

    public function name(): string
    {
        return $this->name;
    }

    public function description(): ?string
    {
        return $this->description;
    }

    public function servings(): int
    {
        return $this->servings;
    }

    public function createdAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }
}
