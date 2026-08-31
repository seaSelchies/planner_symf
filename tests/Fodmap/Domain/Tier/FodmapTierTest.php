<?php

namespace App\Tests\Fodmap\Domain\Tier;

use App\Fodmap\Domain\Tier\FodmapTier;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

/**
 * Covers C10, C11, C12, C15, C29, C31 from docs/specs/use-fodmap-streak.md.
 *
 * C13 (`isBad(null)`) and C14 (`isBad(undefined)`) have no counterpart here: FodmapTier::isBad()
 * takes an already-resolved FodmapTier, never a nullable raw value. A missing/null tier is
 * normalized to FodmapTier::Unknown before isBad() is ever called, which is exactly what the C15
 * case below already asserts — see tests/Fodmap/CASE-COVERAGE.md.
 *
 * C29–C32 originally covered a two-source precedence rule (IngredientTierPrecedence), retired at
 * /contract once the schema showed only one source (ingredient_id → ingredients.fodmap_tier)
 * remains on either side.
 * FodmapTier::orUnknown() takes a single nullable tier, so only C29 and C31 still have a
 * realizable input whose resolved tier matches what the spec expects — both are covered below.
 *
 * C30 and C32 are NOT covered here, and deliberately so: their realizable inputs under the new
 * single-source shape resolve to Unknown, not the "moderate" / "low" the spec records for them.
 * That is a genuine behavior divergence forced by the schema (the recipe-side column both
 * originally fell back to no longer exists), not an oversight — see
 * tests/Fodmap/CASE-COVERAGE.md, rows C30 and C32, for the full accounting. Asserting the spec's old expected value
 * here would fail against real behavior; asserting the new value would misrepresent it as
 * "covering" a case whose actual spec expectation the port cannot produce.
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

    #[DataProvider('orUnknownCases')]
    public function testOrUnknown(?FodmapTier $catalogueTier, FodmapTier $expected): void
    {
        self::assertSame($expected, FodmapTier::orUnknown($catalogueTier));
    }

    public static function orUnknownCases(): iterable
    {
        yield 'C29 a tier on record is returned unchanged' => [
            FodmapTier::Low, FodmapTier::Low,
        ];
        yield 'C31 nothing on record resolves to unknown (also C30\'s realizable input — see tests/Fodmap/CASE-COVERAGE.md)' => [
            null, FodmapTier::Unknown,
        ];
    }
}
