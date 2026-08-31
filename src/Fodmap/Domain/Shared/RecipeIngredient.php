<?php

namespace App\Fodmap\Domain\Shared;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'recipe_ingredients')]
class RecipeIngredient
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    #[ORM\ManyToOne(targetEntity: Recipe::class)]
    #[ORM\JoinColumn(name: 'recipe_id', referencedColumnName: 'id', nullable: false, onDelete: 'CASCADE')]
    private Recipe $recipe;

    // schema.sql declares `amount numeric` with no precision/scale (unconstrained); Doctrine's
    // decimal type has no unconstrained form, so precision/scale are chosen here rather than
    // read off the source — see the /entity report.
    #[ORM\Column(type: 'decimal', precision: 10, scale: 3, nullable: true)]
    private ?string $amount = null;

    #[ORM\Column(type: 'text', nullable: true)]
    private ?string $unit = null;

    #[ORM\ManyToOne(targetEntity: Ingredient::class)]
    #[ORM\JoinColumn(name: 'ingredient_id', referencedColumnName: 'id', nullable: true, onDelete: 'SET NULL')]
    private ?Ingredient $ingredient = null;

    public function id(): string
    {
        return $this->id;
    }

    public function recipe(): Recipe
    {
        return $this->recipe;
    }

    public function amount(): ?string
    {
        return $this->amount;
    }

    public function unit(): ?string
    {
        return $this->unit;
    }

    public function ingredient(): ?Ingredient
    {
        return $this->ingredient;
    }
}
