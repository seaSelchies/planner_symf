<?php

namespace App\Tests\Tag\Adapter\Http\Controllers;

use App\Shared\Domain\Bus\Command\Command;
use App\Shared\Domain\Bus\Command\CommandBus;

final class FakeCommandBus implements CommandBus
{
    private ?Command $dispatchedCommand = null;

    public function __construct(
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function dispatch(Command $command): void
    {
        $this->dispatchedCommand = $command;

        if ($this->throws !== null) {
            throw $this->throws;
        }
    }

    public function dispatchedCommand(): ?Command
    {
        return $this->dispatchedCommand;
    }
}
