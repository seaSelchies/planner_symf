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
        return $this === self::Moderate || $this === self::High;
    }

    public static function orUnknown(?self $catalogueTier): self
    {
        return $catalogueTier ?? self::Unknown;
    }
}
