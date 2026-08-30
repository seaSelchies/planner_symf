<?php

namespace App\Tests\Fodmap\Domain\MealPlan;

use App\Fodmap\Domain\MealPlan\IngredientTierPrecedence;
use App\Fodmap\Domain\Tier\FodmapTier;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Covers C29, C30, C31, C32 from docs/specs/use-fodmap-streak.md.
 *
 * IngredientTierPrecedence was added to /contract's declarations after the original
 * tests/Fodmap/CASE-COVERAGE.md reported these four cases as having no unit-testable home (see
 * docs/todo/fodmap-streak-ingredient-tier-precedence.md). These cases were "Not covered" there;
 * this file is what covers them now, and tests/Fodmap/CASE-COVERAGE.md records that.
 *
 * The adapter converts each raw column independently with FodmapTier::tryFrom() before calling
 * resolve(), so "no joined catalogue row" and "joined row present but its fodmap_tier is null"
 * both arrive here as $catalogueTier === null — the two C32/C30 scenarios are indistinguishable
 * by the time Domain sees them, exactly as the specification describes (the null is nullish-
 * coalesced past, not treated as a distinct case).
 */
final class IngredientTierPrecedenceTest extends TestCase
{
    #[DataProvider('precedenceCases')]
    public function testResolve(?FodmapTier $catalogueTier, ?FodmapTier $recipeTier, FodmapTier $expected): void
    {
        $resolved = (new IngredientTierPrecedence())->resolve($catalogueTier, $recipeTier);

        self::assertSame($expected, $resolved);
    }

    public static function precedenceCases(): iterable
    {
        yield 'C29 catalogue tier wins over a different recipe column tier' => [
            FodmapTier::Low, FodmapTier::High, FodmapTier::Low,
        ];

        yield 'C30 no joined catalogue row falls back to the recipe column' => [
            null, FodmapTier::Moderate, FodmapTier::Moderate,
        ];

        yield 'C31 neither source present resolves to unknown' => [
            null, null, FodmapTier::Unknown,
        ];

        yield 'C32 joined catalogue row present but null falls to the recipe column, not straight to unknown' => [
            null, FodmapTier::Low, FodmapTier::Low,
        ];
    }
}
