<?php

namespace App\Tests\Fodmap\Adapter\Http\Controllers;

use App\Shared\Domain\Bus\Query\Query;
use App\Shared\Domain\Bus\Query\QueryBus;
use App\Shared\Domain\Bus\Query\Response;

final class FakeQueryBus implements QueryBus
{
    public function __construct(
        private readonly ?Response $response = null,
        private readonly ?\Throwable $throws = null,
    ) {
    }

    public function ask(Query $query): Response
    {
        if ($this->throws !== null) {
            throw $this->throws;
        }

        return $this->response;
    }
}
