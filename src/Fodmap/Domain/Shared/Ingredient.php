<?php

namespace App\Fodmap\Domain\Shared;

use Doctrine\ORM\Mapping as ORM;

// Non-final: Doctrine needs to proxy this class (invariant 16, the one exception).
#[ORM\Entity]
#[ORM\Table(name: 'ingredients')]
class Ingredient
{
    #[ORM\Id]
    #[ORM\Column(type: 'guid')]
    private string $id;

    // Made nullable in migration 022: rows whose name_en held Cyrillic text had it moved to
    // name_ru and cleared here, so the app falls back to name_ru for those rows.
    #[ORM\Column(name: 'name_en', type: 'text', nullable: true)]
    private ?string $nameEn = null;

    #[ORM\Column(name: 'name_ru', type: 'text', nullable: true)]
    private ?string $nameRu = null;

    #[ORM\Column(name: 'fodmap_tier', type: 'text', options: ['default' => 'unknown'])]
    private string $fodmapTier = 'unknown';

    #[ORM\Column(name: 'notes_en', type: 'text', nullable: true)]
    private ?string $notesEn = null;

    #[ORM\Column(name: 'notes_ru', type: 'text', nullable: true)]
    private ?string $notesRu = null;

    #[ORM\Column(name: 'created_at', type: 'datetimetz_immutable')]
    private \DateTimeImmutable $createdAt;

    public function id(): string
    {
        return $this->id;
    }

    public function nameEn(): ?string
    {
        return $this->nameEn;
    }

    public function nameRu(): ?string
    {
        return $this->nameRu;
    }

    public function fodmapTier(): string
    {
        return $this->fodmapTier;
    }

    public function notesEn(): ?string
    {
        return $this->notesEn;
    }

    public function notesRu(): ?string
    {
        return $this->notesRu;
    }

    public function createdAt(): \DateTimeImmutable
    {
        return $this->createdAt;
    }
}
