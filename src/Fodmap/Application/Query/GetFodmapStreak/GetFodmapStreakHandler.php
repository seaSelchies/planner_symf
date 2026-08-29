<?php

namespace App\Fodmap\Application\Query\GetFodmapStreak;

use App\Fodmap\Domain\MealLog\LoggedTierProvider;
use App\Fodmap\Domain\MealPlan\PlannedTierProvider;
use App\Fodmap\Domain\Streak\FodmapStreakCalculator;
use App\Shared\Domain\Bus\Query\QueryHandler;
use Symfony\Component\Clock\ClockInterface;

final class GetFodmapStreakHandler implements QueryHandler
{
    public function __construct(
        private readonly PlannedTierProvider $plannedTierProvider,
        private readonly LoggedTierProvider $loggedTierProvider,
        private readonly ClockInterface $clock,
        private readonly FodmapStreakCalculator $calculator,
    ) {
    }

    public function __invoke(GetFodmapStreakQuery $query): GetFodmapStreakResponse
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
