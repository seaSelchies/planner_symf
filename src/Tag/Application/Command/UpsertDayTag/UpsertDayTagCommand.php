<?php

namespace App\Tag\Application\Command\UpsertDayTag;

use App\Shared\Domain\Bus\Command\Command;

final class UpsertDayTagCommand implements Command
{
    public function __construct(
        public readonly string $userId,
        public readonly string $date,
        public readonly string $tag,
        public readonly ?string $notes,
    ) {
    }
}
