<?php

namespace App\Fodmap\Domain\Shared;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'meal_plans')]
#[ORM\UniqueConstraint(name: 'meal_plans_user_week_day_type_unique', columns: ['user_id', 'week_start', 'day_of_week', 'meal_type'])]
class MealPlan
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    #[ORM\Column(name: 'user_id', type: 'guid')]
    private string $userId;

    #[ORM\Column(name: 'week_start', type: 'date')]
    private \DateTimeInterface $weekStart;

    #[ORM\Column(name: 'day_of_week', type: 'integer')]
    private int $dayOfWeek;

    #[ORM\Column(name: 'meal_type', type: 'text')]
    private string $mealType;

    #[ORM\ManyToOne(targetEntity: Recipe::class)]
    #[ORM\JoinColumn(name: 'recipe_id', referencedColumnName: 'id', nullable: true, onDelete: 'SET NULL')]
    private ?Recipe $recipe = null;

    #[ORM\Column(name: 'created_at', type: 'datetimetz_immutable')]
    private \DateTimeImmutable $createdAt;

    #[ORM\Column(name: 'is_leftover', type: 'boolean', options: ['default' => false])]
    private bool $isLeftover = false;

    #[ORM\ManyToOne(targetEntity: self::class)]
    #[ORM\JoinColumn(name: 'leftover_source_id', referencedColumnName: 'id', nullable: true, onDelete: 'SET NULL')]
    private ?self $leftoverSource = null;

    public function id(): string
    {
        return $this->id;
    }

    public function userId(): string
    {
        return $this->userId;
    }

    public function weekStart(): \DateTimeInterface
    {
        return $this->weekStart;
    }

    public function dayOfWeek(): int
    {
        return $this->dayOfWeek;
    }

    public function mealType(): string
    {
        return $this->mealType;
    }

    public function recipe(): ?Recipe
    {
        return $this->recipe;
    }

    public function createdAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }

    public function isLeftover(): bool
    {
        return $this->isLeftover;
    }

    public function leftoverSource(): ?self
    {
        return $this->leftoverSource;
    }
}
