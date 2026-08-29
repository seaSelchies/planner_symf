<?php

namespace App\Fodmap\Domain\Tier;

enum FodmapTier: string
{
    case Low = 'low';
    case Moderate = 'moderate';
    case High = 'high';
    case Unknown = 'unknown';

    public function isBad(): bool
    {
        throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
    }
}
