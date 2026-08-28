<?php

namespace App\Shared\Infrastructure\Bus\Command;

use App\Shared\Domain\Bus\Command\Command;
use App\Shared\Domain\Bus\Command\CommandBus;
use App\Shared\Infrastructure\Bus\HandlerFailureUnwrapper;
use Symfony\Component\Messenger\Exception\HandlerFailedException;
use Symfony\Component\Messenger\MessageBusInterface;

final class MessengerCommandBus implements CommandBus
{
    public function __construct(
        private readonly MessageBusInterface $commandBus,
        private readonly HandlerFailureUnwrapper $unwrapper,
    ) {
    }

    public function dispatch(Command $command): void
    {
        try {
            $this->commandBus->dispatch($command);
        } catch (HandlerFailedException $exception) {
            throw $this->unwrapper->unwrap($exception);
        }
    }
}
