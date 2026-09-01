<?php

namespace App\Tag\Adapter\Http\Controllers;

use App\Shared\Domain\Bus\Command\CommandBus;
use App\Tag\Application\Command\UpdateDayTagNote\UpdateDayTagNoteCommand;
use App\Tag\Domain\DayTagNotFoundException;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

final class ApiUpdateDayTagNoteController
{
    // Placeholder until an Auth module resolves the real current user — see
    // docs/todo/day-tags-user-scoping.md.
    private const PLACEHOLDER_USER_ID = '325c4450-a5b7-46e8-aee5-9d9a5e2d0bb1';

    public function __construct(
        private readonly CommandBus $commandBus,
    ) {
    }

    #[Route('/api/tags/{id}', name: 'api_update_day_tag_note', methods: ['PATCH'])]
    public function __invoke(string $id, Request $request): JsonResponse
    {
        $payload = json_decode($request->getContent(), true);

        try {
            $this->commandBus->dispatch(new UpdateDayTagNoteCommand(
                self::PLACEHOLDER_USER_ID,
                $id,
                $payload['notes'] ?? null,
            ));
        } catch (DayTagNotFoundException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 404);
        }

        return new JsonResponse('null', 200, [], true);
    }
}
