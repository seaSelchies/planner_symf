<?php

namespace App\Fodmap\Infrastructure\DB;

use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\MealLog\LoggedTierProvider;
use App\Fodmap\Domain\Shared\MealLog;
use App\Fodmap\Domain\Shared\MealLogIngredient;
use App\Fodmap\Domain\Streak\LookbackWindow;
use App\Fodmap\Domain\Tier\FodmapTier;
use Doctrine\DBAL\Exception as DBALException;
use Doctrine\DBAL\Types\Types;
use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\Exception\ORMException;

final class DoctrineLoggedTierProvider implements LoggedTierProvider
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
    ) {
    }

    /**
     * @throws FodmapDataFetchException
     */
    public function loggedTiersByDate(string $userId, \DateTimeImmutable $today): array
    {
        try {
            return $this->fetch($userId, $today);
        } catch (DBALException|ORMException $e) {
            throw new FodmapDataFetchException('Failed to fetch logged FODMAP tiers.', previous: $e);
        }
    }

    /**
     * @return array<string, FodmapTier[]>
     */
    private function fetch(string $userId, \DateTimeImmutable $today): array
    {
        $earliestDate = $today->modify(sprintf('-%d days', LookbackWindow::WEEKS * 7));

        // Only the columns the streak calculation needs are selected — never the whole entity —
        // so a column this module has no use for (created_at) never has to be hydrated at all.
        $logRows = $this->entityManager->createQueryBuilder()
            ->select('l.id AS id', 'l.date AS date')
            ->from(MealLog::class, 'l')
            ->where('l.userId = :userId')
            ->andWhere('l.date BETWEEN :earliestDate AND :today')
            ->setParameter('userId', $userId)
            ->setParameter('earliestDate', $earliestDate, Types::DATE_IMMUTABLE)
            ->setParameter('today', $today, Types::DATE_IMMUTABLE)
            ->getQuery()
            ->getArrayResult();

        $logIds = array_map(static fn (array $row): string => $row['id'], $logRows);

        $tiersByLog = [];
        if ($logIds !== []) {
            $ingredientRows = $this->entityManager->createQueryBuilder()
                ->select('IDENTITY(mli.mealLog) AS logId', 'i.fodmapTier AS fodmapTier')
                ->from(MealLogIngredient::class, 'mli')
                ->leftJoin('mli.ingredient', 'i')
                ->where('IDENTITY(mli.mealLog) IN (:logIds)')
                ->setParameter('logIds', $logIds)
                ->getQuery()
                ->getArrayResult();

            foreach ($ingredientRows as $row) {
                $catalogueTier = $row['fodmapTier'] !== null ? FodmapTier::tryFrom($row['fodmapTier']) : null;
                $tiersByLog[$row['logId']][] = FodmapTier::orUnknown($catalogueTier);
            }
        }

        $tiersByDate = [];

        foreach ($logRows as $row) {
            $tiers = $tiersByLog[$row['id']] ?? [];

            if ($tiers === []) {
                // C18, C19: a logged meal with zero ingredients is treated as not logged at all —
                // no entry is created, so the streak calculator falls through to plan data.
                continue;
            }

            $dateKey = $row['date']->format('Y-m-d');
            $tiersByDate[$dateKey] = array_merge($tiersByDate[$dateKey] ?? [], $tiers);
        }

        return $tiersByDate;
    }
}
