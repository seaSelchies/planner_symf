<?php

namespace App\Tag\Application\Query\GetDayTags;

use App\Shared\Domain\Bus\Query\QueryHandler;
use App\Tag\Domain\DayTagProvider;

final class GetDayTagsHandler implements QueryHandler
{
    public function __construct(
        private readonly DayTagProvider $provider,
    ) {
    }

    public function __invoke(GetDayTagsQuery $query): GetDayTagsResponse
    {
        return new GetDayTagsResponse($this->provider->tagsForDates($query->userId, $query->dates));
    }
}
