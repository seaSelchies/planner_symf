<?php

namespace App\Tag\Application\Command\UpdateDayTagNote;

use App\Shared\Domain\Bus\Command\CommandHandler;
use App\Tag\Domain\DayTagRepository;

final class UpdateDayTagNoteHandler implements CommandHandler
{
    public function __construct(
        private readonly DayTagRepository $repository,
    ) {
    }

    public function __invoke(UpdateDayTagNoteCommand $command): void
    {
        $this->repository->updateNotes($command->userId, $command->id, $command->notes);
    }
}
