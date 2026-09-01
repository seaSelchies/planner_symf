<?php

namespace App\Tag\Application\Command\UpsertDayTag;

use App\Shared\Domain\Bus\Command\CommandHandler;
use App\Tag\Domain\DayTagProvider;
use App\Tag\Domain\DayTagRepository;

final class UpsertDayTagHandler implements CommandHandler
{
    public function __construct(
        private readonly DayTagProvider $provider,
        private readonly DayTagRepository $repository,
    ) {
    }

    public function __invoke(UpsertDayTagCommand $command): void
    {
        $existing = $this->provider->findByUserDateTag($command->userId, $command->date, $command->tag);

        if ($existing !== null) {
            $this->repository->updateNotes($command->userId, $existing->id(), $command->notes);

            return;
        }

        $this->repository->create($command->userId, $command->date, $command->tag, $command->notes);
    }
}
