<?php

namespace App\Tests\Fodmap\Domain\MealPlan;

use App\Fodmap\Domain\MealPlan\MealPlanDate;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Covers C4, C5, C6 from docs/specs/use-fodmap-streak.md.
 */
final class MealPlanDateTest extends TestCase
{
    #[DataProvider('dateCases')]
    public function testResolve(string $weekStart, int $dayOfWeek, string $expectedIsoDate): void
    {
        $resolved = (new MealPlanDate())->resolve(new \DateTimeImmutable($weekStart), $dayOfWeek);

        self::assertSame($expectedIsoDate, $resolved->format('Y-m-d'));
    }

    public static function dateCases(): iterable
    {
        yield 'C4 day_of_week 0 is week_start itself' => ['2026-08-24', 0, '2026-08-24'];
        yield 'C5 day_of_week 6 is six days after week_start' => ['2026-08-24', 6, '2026-08-30'];
        yield 'C6 day_of_week 7 is out of range and silently rolls into the next week' => [
            '2026-08-24', 7, '2026-08-31',
        ];
    }
}
