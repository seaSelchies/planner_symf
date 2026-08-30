<?php

namespace App\Fodmap\Adapter\Http\Controllers;

use App\Fodmap\Application\Query\GetFodmapStreak\GetFodmapStreakQuery;
use App\Fodmap\Application\Query\GetFodmapStreak\GetFodmapStreakResponse;
use App\Fodmap\Domain\FodmapDataFetchException;
use App\Shared\Domain\Bus\Query\QueryBus;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

final class ApiGetFodmapStreakController
{
    public function __construct(
        private readonly QueryBus $queryBus,
    ) {
    }

    #[Route('/api/fodmap/streak', name: 'api_get_fodmap_streak', methods: ['GET'])]
    public function __invoke(): JsonResponse
    {
        try {
            /** @var GetFodmapStreakResponse $response */
            $response = $this->queryBus->ask(new GetFodmapStreakQuery());
        } catch (FodmapDataFetchException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 503);
        }

        return new JsonResponse(['streak' => $response->streak]);
    }
}
