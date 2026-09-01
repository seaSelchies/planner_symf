<?php

namespace App\Tag\Adapter\Http\Controllers;

use App\Shared\Domain\Bus\Command\CommandBus;
use App\Tag\Application\Command\RemoveDayTag\RemoveDayTagCommand;
use App\Tag\Domain\DayTagDataFetchException;
use App\Tag\Domain\DayTagNotFoundException;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\Routing\Attribute\Route;

final class ApiRemoveDayTagController
{
    // Placeholder until an Auth module resolves the real current user — see
    // docs/todo/day-tags-user-scoping.md.
    private const PLACEHOLDER_USER_ID = '325c4450-a5b7-46e8-aee5-9d9a5e2d0bb1';

    public function __construct(
        private readonly CommandBus $commandBus,
    ) {
    }

    #[Route('/api/tags/{date}/{tag}', name: 'api_remove_day_tag', methods: ['DELETE'])]
    public function __invoke(string $date, string $tag): JsonResponse
    {
        try {
            $this->commandBus->dispatch(new RemoveDayTagCommand(self::PLACEHOLDER_USER_ID, $date, $tag));
        } catch (DayTagNotFoundException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 404);
        } catch (DayTagDataFetchException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 503);
        }

        return new JsonResponse('null', 200, [], true);
    }
}
