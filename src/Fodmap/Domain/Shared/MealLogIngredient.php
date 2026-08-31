<?php

namespace App\Fodmap\Domain\Shared;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'meal_log_ingredients')]
class MealLogIngredient
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    #[ORM\ManyToOne(targetEntity: MealLog::class)]
    #[ORM\JoinColumn(name: 'meal_log_id', referencedColumnName: 'id', nullable: false, onDelete: 'CASCADE')]
    private MealLog $mealLog;

    #[ORM\ManyToOne(targetEntity: Ingredient::class)]
    #[ORM\JoinColumn(name: 'ingredient_id', referencedColumnName: 'id', nullable: true, onDelete: 'SET NULL')]
    private ?Ingredient $ingredient = null;

    public function id(): string
    {
        return $this->id;
    }

    public function mealLog(): MealLog
    {
        return $this->mealLog;
    }

    public function ingredient(): ?Ingredient
    {
        return $this->ingredient;
    }
}
