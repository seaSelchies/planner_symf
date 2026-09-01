<?php

namespace App\Tag\Adapter\Http\Controllers;

use App\Shared\Domain\Bus\Command\CommandBus;
use App\Tag\Application\Command\UpsertDayTag\UpsertDayTagCommand;
use App\Tag\Domain\DayTagAlreadyExistsException;
use App\Tag\Domain\DayTagDataFetchException;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

final class ApiUpsertDayTagController
{
    // Placeholder until an Auth module resolves the real current user — see
    // docs/todo/day-tags-user-scoping.md.
    private const PLACEHOLDER_USER_ID = '325c4450-a5b7-46e8-aee5-9d9a5e2d0bb1';

    public function __construct(
        private readonly CommandBus $commandBus,
    ) {
    }

    #[Route('/api/tags', name: 'api_upsert_day_tag', methods: ['PUT'])]
    public function __invoke(Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        try {
            $this->commandBus->dispatch(new UpsertDayTagCommand(
                self::PLACEHOLDER_USER_ID,
                $payload['date'],
                $payload['tag'],
                $payload['notes'] ?? null,
            ));
        } catch (DayTagAlreadyExistsException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 409);
        } catch (DayTagDataFetchException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 503);
        }

        return new JsonResponse('null', 200, [], true);
    }
}
