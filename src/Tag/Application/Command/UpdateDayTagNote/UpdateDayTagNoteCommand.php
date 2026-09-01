<?php

namespace App\Tag\Application\Command\UpdateDayTagNote;

use App\Shared\Domain\Bus\Command\Command;

final class UpdateDayTagNoteCommand implements Command
{
    public function __construct(
        public readonly string $userId,
        public readonly string $id,
        public readonly ?string $notes,
    ) {
    }
}
