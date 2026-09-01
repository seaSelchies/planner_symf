<?php

namespace App\Tag\Application\Command\RemoveDayTag;

use App\Shared\Domain\Bus\Command\CommandHandler;
use App\Tag\Domain\DayTagNotFoundException;
use App\Tag\Domain\DayTagProvider;
use App\Tag\Domain\DayTagRepository;

final class RemoveDayTagHandler implements CommandHandler
{
    public function __construct(
        private readonly DayTagProvider $provider,
        private readonly DayTagRepository $repository,
    ) {
    }

    public function __invoke(RemoveDayTagCommand $command): void
    {
        $existing = $this->provider->findByUserDateTag($command->userId, $command->date, $command->tag);

        if ($existing === null) {
            throw new DayTagNotFoundException(sprintf(
                'No day tag found for user %s, date %s, tag %s.',
                $command->userId,
                $command->date,
                $command->tag,
            ));
        }

        $this->repository->delete($command->userId, $existing->id());
    }
}
