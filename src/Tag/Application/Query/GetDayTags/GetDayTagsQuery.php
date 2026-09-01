<?php

namespace App\Tag\Application\Query\GetDayTags;

use App\Shared\Domain\Bus\Query\Query;

final class GetDayTagsQuery implements Query
{
    /**
     * @param string[] $dates ISO-8601 (Y-m-d) dates
     */
    public function __construct(
        public readonly string $userId,
        public readonly array $dates,
    ) {
    }
}
