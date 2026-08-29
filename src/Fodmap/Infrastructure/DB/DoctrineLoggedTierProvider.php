<?php

namespace App\Fodmap\Infrastructure\DB;

use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\MealLog\LoggedTierProvider;
use Doctrine\DBAL\Connection;

final class DoctrineLoggedTierProvider implements LoggedTierProvider
{
    public function __construct(
        private readonly Connection $connection,
    ) {
    }

    /**
     * @throws FodmapDataFetchException
     */
    public function loggedTiersByDate(\DateTimeImmutable $today): array
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
