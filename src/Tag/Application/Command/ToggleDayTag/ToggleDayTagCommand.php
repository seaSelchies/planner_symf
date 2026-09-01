<?php

namespace App\Tag\Application\Command\ToggleDayTag;

use App\Shared\Domain\Bus\Command\Command;

final class ToggleDayTagCommand implements Command
{
    public function __construct(
        public readonly string $userId,
        public readonly string $date,
        public readonly string $tag,
    ) {
    }
}
