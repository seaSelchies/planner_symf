<?php

namespace App\Fodmap\Infrastructure\DB;

use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\MealPlan\PlannedTierProvider;
use Doctrine\DBAL\Connection;

final class DoctrinePlannedTierProvider implements PlannedTierProvider
{
    public function __construct(
        private readonly Connection $connection,
    ) {
    }

    /**
     * @throws FodmapDataFetchException
     */
    public function plannedTiersByDate(\DateTimeImmutable $today): array
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
