<?php

namespace App\Shared\Infrastructure\Bus;

use Symfony\Component\Messenger\Exception\HandlerFailedException;
use Throwable;

final class HandlerFailureUnwrapper
{
    public function unwrap(HandlerFailedException $exception): Throwable
    {
        $wrapped = $exception->getWrappedExceptions();
        $first = reset($wrapped);

        if (!$first instanceof Throwable) {
            return $exception;
        }

        return $first instanceof HandlerFailedException ? $this->unwrap($first) : $first;
    }
}
