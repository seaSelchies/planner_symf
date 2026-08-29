<?php

namespace App\Fodmap\Application\Query\GetFodmapStreak;

use App\Shared\Domain\Bus\Query\Response;

final class GetFodmapStreakResponse implements Response
{
    public function __construct(
        public readonly int $streak,
    ) {
    }
}
