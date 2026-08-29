<?php

namespace App\Tests\Fodmap\Domain\Streak;

use App\Fodmap\Domain\Streak\FodmapStreakCalculator;
use App\Fodmap\Domain\Tier\FodmapTier;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Covers C16, C17, C18, C19, C20, C21, C23, C24 in full, and the day-safety half of C27 and C28
 * (a date's tier list already containing more than one tier, some bad) from
 * docs/specs/use-fodmap-streak.md.
 *
 * The "C25 mechanism" case exercises the rule that the streak stops the instant a day is absent
 * from both maps — this is the actual mechanism behind C25's ~112-118 day cap, but the specific
 * magnitude is an Infrastructure window-size detail with no Domain counterpart.
 *
 * C22, and the "two DB rows get concatenated into one array" half of C27/C28, are Infrastructure
 * map-construction behavior with no Domain counterpart yet. See tests/Fodmap/CASE-COVERAGE.md.
 */
final class FodmapStreakCalculatorTest extends TestCase
{
    #[DataProvider('streakCases')]
    public function testStreak(array $loggedTiersByDate, array $plannedTiersByDate, int $expectedStreak): void
    {
        $streak = (new FodmapStreakCalculator())->streak(
            $loggedTiersByDate,
            $plannedTiersByDate,
            new \DateTimeImmutable('2026-08-29'),
        );

        self::assertSame($expectedStreak, $streak);
    }

    public static function streakCases(): iterable
    {
        yield 'C16 today logged low,low is safe' => [
            ['2026-08-29' => [FodmapTier::Low, FodmapTier::Low]],
            [],
            1,
        ];

        yield 'C17 today logged low,high is unsafe' => [
            ['2026-08-29' => [FodmapTier::Low, FodmapTier::High]],
            [],
            0,
        ];

        yield 'C18 today logged with zero ingredients and no plan is unsafe, no data' => [
            [],
            [],
            0,
        ];

        yield 'C19 today logged with zero ingredients falls back to a safe plan' => [
            [],
            ['2026-08-29' => [FodmapTier::Low]],
            1,
        ];

        yield 'C20 today logged with all-null tiers maps to unknown, counted safe' => [
            ['2026-08-29' => [FodmapTier::Unknown, FodmapTier::Unknown]],
            [],
            1,
        ];

        yield 'C21 today has a plan resolving to zero ingredient rows, still unsafe' => [
            [],
            ['2026-08-29' => []],
            0,
        ];

        yield 'C23 today and yesterday safe, day before has a moderate tier, streak is 2' => [
            [
                '2026-08-29' => [FodmapTier::Low],
                '2026-08-28' => [FodmapTier::Low],
                '2026-08-27' => [FodmapTier::Moderate],
            ],
            [],
            2,
        ];

        yield 'C24 today unsafe, no data at all, streak is 0' => [
            [],
            [],
            0,
        ];

        yield 'C25 mechanism: streak stops the instant a day is absent from both maps' => [
            [
                '2026-08-29' => [FodmapTier::Low],
                '2026-08-28' => [FodmapTier::Low],
                '2026-08-27' => [FodmapTier::Low],
            ],
            [],
            3,
        ];

        yield 'C27 day-safety half: two concatenated planned tiers, one moderate, is unsafe' => [
            [],
            ['2026-08-29' => [FodmapTier::Low, FodmapTier::Moderate]],
            0,
        ];

        yield 'C28 day-safety half: two concatenated logged tiers, one high, is unsafe' => [
            ['2026-08-29' => [FodmapTier::Low, FodmapTier::High]],
            [],
            0,
        ];
    }
}
