<?php

namespace App\Fodmap\Domain\Streak;

/**
 * The one window definition both DoctrinePlannedTierProvider and DoctrineLoggedTierProvider
 * derive their date range from, per docs/todo/fodmap-streak-lookback-window.md — so the two
 * sources cannot silently disagree on how far back they look. The concrete length (16 weeks,
 * matching the original's literal 16 Mondays / 112 days) and whether it becomes configurable are
 * left open by that todo; this is the default it explicitly allows.
 */
final class LookbackWindow
{
    public const WEEKS = 16;
}
