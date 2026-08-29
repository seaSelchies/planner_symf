<?php

namespace App\Tests\Fodmap\Domain\Tier;

use App\Fodmap\Domain\Tier\FodmapTier;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Covers C10, C11, C12, C15 from docs/specs/use-fodmap-streak.md.
 *
 * C13 (`isBad(null)`) and C14 (`isBad(undefined)`) have no counterpart here: FodmapTier::isBad()
 * takes an already-resolved FodmapTier, never a nullable raw value. A missing/null tier is
 * normalized to FodmapTier::Unknown before isBad() is ever called, which is exactly what the C15
 * case below already asserts — see tests/Fodmap/CASE-COVERAGE.md.
 */
final class FodmapTierTest extends TestCase
{
    #[DataProvider('tierCases')]
    public function testIsBad(FodmapTier $tier, bool $expected): void
    {
        self::assertSame($expected, $tier->isBad());
    }

    public static function tierCases(): iterable
    {
        yield 'C10 moderate is bad' => [FodmapTier::Moderate, true];
        yield 'C11 high is bad' => [FodmapTier::High, true];
        yield 'C12 low is not bad' => [FodmapTier::Low, false];
        yield 'C15 unknown is not bad' => [FodmapTier::Unknown, false];
    }
}
