<?php

namespace App\Fodmap\Infrastructure\DB;

use App\Fodmap\Domain\FodmapDataFetchException;
use App\Fodmap\Domain\MealPlan\MealPlanDate;
use App\Fodmap\Domain\MealPlan\PlannedTierProvider;
use App\Fodmap\Domain\MealPlan\RecentMondays;
use App\Fodmap\Domain\Shared\MealPlan;
use App\Fodmap\Domain\Shared\RecipeIngredient;
use App\Fodmap\Domain\Streak\LookbackWindow;
use App\Fodmap\Domain\Tier\FodmapTier;
use Doctrine\DBAL\ArrayParameterType;
use Doctrine\DBAL\Exception as DBALException;
use Doctrine\ORM\EntityManagerInterface;
use Doctrine\ORM\Exception\ORMException;

final class DoctrinePlannedTierProvider implements PlannedTierProvider
{
    public function __construct(
        private readonly EntityManagerInterface $entityManager,
    ) {
    }

    /**
     * @throws FodmapDataFetchException
     */
    public function plannedTiersByDate(string $userId, \DateTimeImmutable $today): array
    {
        try {
            return $this->fetch($userId, $today);
        } catch (DBALException|ORMException $e) {
            throw new FodmapDataFetchException('Failed to fetch planned FODMAP tiers.', previous: $e);
        }
    }

    /**
     * @return array<string, FodmapTier[]>
     */
    private function fetch(string $userId, \DateTimeImmutable $today): array
    {
        $mondays = (new RecentMondays())->lastN($today, LookbackWindow::WEEKS);

        // Only the columns the streak calculation needs are selected — never the whole entity —
        // so a column this module has no use for (created_at) never has to be hydrated at all.
        $planRows = $this->entityManager->createQueryBuilder()
            ->select('p.id AS id', 'p.weekStart AS weekStart', 'p.dayOfWeek AS dayOfWeek', 'IDENTITY(p.recipe) AS recipeId')
            ->from(MealPlan::class, 'p')
            ->where('p.userId = :userId')
            ->andWhere('p.weekStart IN (:mondays)')
            ->setParameter('userId', $userId)
            ->setParameter(
                'mondays',
                array_map(static fn (\DateTimeImmutable $monday): string => $monday->format('Y-m-d'), $mondays),
                ArrayParameterType::STRING,
            )
            ->getQuery()
            ->getArrayResult();

        $recipeIds = [];
        foreach ($planRows as $row) {
            if ($row['recipeId'] !== null) {
                $recipeIds[$row['recipeId']] = $row['recipeId'];
            }
        }

        $tiersByRecipe = [];
        if ($recipeIds !== []) {
            $ingredientRows = $this->entityManager->createQueryBuilder()
                ->select('IDENTITY(ri.recipe) AS recipeId', 'i.fodmapTier AS fodmapTier')
                ->from(RecipeIngredient::class, 'ri')
                ->leftJoin('ri.ingredient', 'i')
                ->where('IDENTITY(ri.recipe) IN (:recipeIds)')
                ->setParameter('recipeIds', array_values($recipeIds))
                ->getQuery()
                ->getArrayResult();

            foreach ($ingredientRows as $row) {
                $catalogueTier = $row['fodmapTier'] !== null ? FodmapTier::tryFrom($row['fodmapTier']) : null;
                $tiersByRecipe[$row['recipeId']][] = FodmapTier::orUnknown($catalogueTier);
            }
        }

        $mealPlanDate = new MealPlanDate();
        $tiersByDate = [];

        foreach ($planRows as $row) {
            $weekStart = \DateTimeImmutable::createFromInterface($row['weekStart']);
            $date = $mealPlanDate->resolve($weekStart, (int) $row['dayOfWeek']);

            if ($date > $today) {
                continue;
            }

            $dateKey = $date->format('Y-m-d');
            $recipeId = $row['recipeId'];
            $tiers = $recipeId !== null ? ($tiersByRecipe[$recipeId] ?? []) : [];

            $tiersByDate[$dateKey] = array_merge($tiersByDate[$dateKey] ?? [], $tiers);
        }

        return $tiersByDate;
    }
}
