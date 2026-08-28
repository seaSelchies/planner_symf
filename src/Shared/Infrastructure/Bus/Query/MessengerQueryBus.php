<?php

namespace App\Shared\Infrastructure\Bus\Query;

use App\Shared\Domain\Bus\Query\Query;
use App\Shared\Domain\Bus\Query\QueryBus;
use App\Shared\Domain\Bus\Query\Response;
use App\Shared\Infrastructure\Bus\HandlerFailureUnwrapper;
use Symfony\Component\Messenger\Exception\HandlerFailedException;
use Symfony\Component\Messenger\HandleTrait;
use Symfony\Component\Messenger\MessageBusInterface;

final class MessengerQueryBus implements QueryBus
{
    use HandleTrait;

    public function __construct(
        MessageBusInterface $queryBus,
        private readonly HandlerFailureUnwrapper $unwrapper,
    ) {
        $this->messageBus = $queryBus;
    }

    public function ask(Query $query): Response
    {
        try {
            return $this->handle($query);
        } catch (HandlerFailedException $exception) {
            throw $this->unwrapper->unwrap($exception);
        }
    }
}
