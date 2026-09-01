<?php

namespace App\Tag\Application\Command\RemoveDayTag;

use App\Shared\Domain\Bus\Command\Command;

final class RemoveDayTagCommand implements Command
{
    public function __construct(
        public readonly string $userId,
        public readonly string $date,
        public readonly string $tag,
    ) {
    }
}
