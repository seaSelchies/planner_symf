<?php

namespace App\Tag\Application\Command\ToggleDayTag;

use App\Shared\Domain\Bus\Command\CommandHandler;
use App\Tag\Domain\DayTagProvider;
use App\Tag\Domain\DayTagRepository;

final class ToggleDayTagHandler implements CommandHandler
{
    public function __construct(
        private readonly DayTagProvider $provider,
        private readonly DayTagRepository $repository,
    ) {
    }

    public function __invoke(ToggleDayTagCommand $command): void
    {
        $existing = $this->provider->findByUserDateTag($command->userId, $command->date, $command->tag);

        if ($existing !== null) {
            $this->repository->delete($command->userId, $existing->id());

            return;
        }

        $this->repository->create($command->userId, $command->date, $command->tag, null);
    }
}
