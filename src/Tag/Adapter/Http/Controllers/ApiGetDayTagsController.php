<?php

namespace App\Tag\Adapter\Http\Controllers;

use App\Shared\Domain\Bus\Query\QueryBus;
use App\Tag\Application\Query\GetDayTags\GetDayTagsQuery;
use App\Tag\Application\Query\GetDayTags\GetDayTagsResponse;
use App\Tag\Domain\DayTag;
use App\Tag\Domain\DayTagDataFetchException;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Attribute\Route;

final class ApiGetDayTagsController
{
    // Placeholder until an Auth module resolves the real current user — see
    // docs/todo/day-tags-user-scoping.md.
    private const PLACEHOLDER_USER_ID = '325c4450-a5b7-46e8-aee5-9d9a5e2d0bb1';

    public function __construct(
        private readonly QueryBus $queryBus,
    ) {
    }

    #[Route('/api/tags', name: 'api_get_day_tags', methods: ['GET'])]
    public function __invoke(Request $request): JsonResponse
    {
        $dates = $request->query->all('dates');
        try {
            /** @var GetDayTagsResponse $response */
            $response = $this->queryBus->ask(new GetDayTagsQuery(self::PLACEHOLDER_USER_ID, $dates));
        } catch (DayTagDataFetchException $e) {
            return new JsonResponse(['error' => $e->getMessage()], 503);
        }

        return new JsonResponse([
            'dayTags' => array_map(
                static fn (DayTag $dayTag): array => [
                    'id' => $dayTag->id(),
                    'date' => $dayTag->date()->format('Y-m-d'),
                    'tag' => $dayTag->tag(),
                    'notes' => $dayTag->notes(),
                    'createdAt' => $dayTag->createdAt()->format(DATE_ATOM),
                ],
                $response->dayTags,
            ),
        ]);
    }
}
