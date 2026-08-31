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
    // Placeholder until an Auth module resolves the real current user — see
    // docs/todo/fodmap-streak-user-scoping.md.
    private const PLACEHOLDER_USER_ID = '325c4450-a5b7-46e8-aee5-9d9a5e2d0bb1';

    public function __construct(
        private readonly QueryBus $queryBus,
    ) {
    }

    #[Route('/api/fodmap/streak', name: 'api_get_fodmap_streak', methods: ['GET'])]
    public function __invoke(): JsonResponse
    {
        try {
            /** @var GetFodmapStreakResponse $response */
            $response = $this->queryBus->ask(new GetFodmapStreakQuery(self::PLACEHOLDER_USER_ID));
        } catch (FodmapDataFetchException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 503);
        }

        return new JsonResponse(['streak' => $response->streak]);
    }
}
