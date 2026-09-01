<?php

namespace App\Tag\Infrastructure\DB;

use Doctrine\DBAL\Platforms\AbstractPlatform;
use Doctrine\DBAL\Types\DateTimeTzImmutableType;
use Doctrine\DBAL\Types\Exception\InvalidFormat;

// Doctrine's stock DateTimeTzImmutableType is hardcoded to parse "Y-m-d H:i:sO" (no fractional
// seconds, a 4-digit UTC offset). day_tags.created_at is a plain `timestamptz` with no explicit
// precision, so Postgres returns microseconds and a 2-digit offset instead — e.g.
// "2026-08-29 04:49:22.247885+00" — which the stock type rejects. This type delegates to
// DateTimeImmutable's own parser, which accepts both shapes.
final class DateTimeTzImmutableMicrosecondsType extends DateTimeTzImmutableType
{
    public function convertToPHPValue(mixed $value, AbstractPlatform $platform): ?\DateTimeImmutable
    {
        if ($value === null || $value instanceof \DateTimeImmutable) {
            return $value;
        }

        try {
            return new \DateTimeImmutable($value);
        } catch (\Exception) {
            throw InvalidFormat::new($value, static::class, 'Y-m-d H:i:s.uP');
        }
    }
}
