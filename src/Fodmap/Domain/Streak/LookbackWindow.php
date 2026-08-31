<?php

namespace App\Fodmap\Domain\Streak;

/**
 * The lookback length both providers share.
 *
 * The two windows share this length and one $today, and stop there: the plan side
 * walks a discrete list of Mondays, the log side a continuous range of days, so
 * their edges do not coincide. That is what the ported source does, and it is kept
 * deliberately rather than unified — see the Edge cases section of
 * docs/specs/use-fodmap-streak.md. There is no test asserting the two agree,
 * because they are not meant to.
 */
final class LookbackWindow
{
    public const WEEKS = 16;
}
