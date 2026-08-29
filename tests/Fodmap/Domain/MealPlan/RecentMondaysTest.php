<?php

namespace App\Tests\Fodmap\Domain\MealPlan;

use App\Fodmap\Domain\MealPlan\RecentMondays;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Covers C7, C8, C9 from docs/specs/use-fodmap-streak.md.
 */
final class RecentMondaysTest extends TestCase
{
    #[DataProvider('windowCases')]
    public function testLastN(string $today, int $n, array $expectedIsoDates): void
    {
        $mondays = (new RecentMondays())->lastN(new \DateTimeImmutable($today), $n);

        self::assertSame($expectedIsoDates, array_map(
            static fn (\DateTimeImmutable $d): string => $d->format('Y-m-d'),
            $mondays,
        ));
    }

    public static function windowCases(): iterable
    {
        yield 'C7 today is Monday, lastN(1) returns today' => ['2026-08-24', 1, ['2026-08-24']];
        yield 'C8 today is Sunday, lastN(1) returns the prior Monday' => ['2026-08-30', 1, ['2026-08-24']];
        yield 'C9 lastN(3), most recent Monday first' => [
            '2026-08-24', 3, ['2026-08-24', '2026-08-17', '2026-08-10'],
        ];
    }
}
