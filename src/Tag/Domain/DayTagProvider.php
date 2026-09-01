<?php

namespace App\Tag\Domain;

interface DayTagProvider
{
    /**
     * @param string[] $dates ISO-8601 (Y-m-d) dates
     *
     * @return DayTag[] every day tag this user has for the given dates; given an empty
     *                   $dates list, returns [] with no query issued
     *
     * @throws DayTagDataFetchException
     */
    public function tagsForDates(string $userId, array $dates): array;

    /**
     * @throws DayTagDataFetchException
     */
    public function findByUserDateTag(string $userId, string $date, string $tag): ?DayTag;
}
