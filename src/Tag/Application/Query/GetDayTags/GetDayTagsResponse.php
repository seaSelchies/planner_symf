<?php

namespace App\Tag\Application\Query\GetDayTags;

use App\Shared\Domain\Bus\Query\Response;
use App\Tag\Domain\DayTag;

final class GetDayTagsResponse implements Response
{
    /**
     * @param DayTag[] $dayTags
     */
    public function __construct(
        public readonly array $dayTags,
    ) {
    }
}
