<?php

namespace App\Fodmap\Adapter\Http\Controllers;

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
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
