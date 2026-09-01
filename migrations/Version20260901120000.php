<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Creates the planner schema as it exists at the end of the Supabase reference
 * migration trail: docs/reference/supabase/schema.sql plus all 28 files under
 * docs/reference/supabase/migrations/, applied in order. Only the *effective*
 * shape survives here — columns a later reference migration dropped (026) and
 * the fodmap_ingredients table it superseded (021/027) are never created.
 *
 * Deviations from the reference, all forced by the target stack:
 *
 *  - auth.users does not exist outside Supabase. Every user_id stays an
 *    unconstrained uuid, matching docs/todo/fodmap-streak-user-scoping.md,
 *    which fixes the application-side user identifier as a plain string. The
 *    project's own users table keys on an integer, so an FK is not available
 *    even in principle.
 *  - Row-level security is not reproduced. Every reference policy is written
 *    against auth.uid(), which has no equivalent here; the same scoping moves
 *    into the queries, per the same todo.
 *  - gen_random_uuid() (pgcrypto, in core since Postgres 13) replaces the
 *    reference's mix of uuid_generate_v4() and gen_random_uuid(), so the
 *    uuid-ossp extension is not required.
 */
final class Version20260901120000 extends AbstractMigration
{
    public function getDescription(): string
    {
        return 'Create the planner schema (profiles, recipes, meal plans, meal logs, ingredients, tags, weight logs)';
    }

    /**
     * Written entirely as raw SQL at the author's explicit instruction, which
     * departs from invariant 7 (schema changes are expressed through the DBAL
     * schema API, with addSql() reserved for constructs that API cannot
     * express). Several constructs here genuinely are in that reserved set —
     * the CHECK constraints on fodmap_tier, meal_type and day_of_week, and the
     * gen_random_uuid() column defaults — but the ordinary tables, foreign
     * keys and unique constraints around them are not, and this migration
     * states them in SQL anyway to keep one readable transcript of the
     * reference schema. Reviewers: this is a known, deliberate divergence, not
     * an oversight.
     */
    public function up(Schema $schema): void
    {
        // Shared, non-user-scoped ingredient catalogue (reference migration 021,
        // name_en made nullable by 022). Created first: recipe_ingredients and
        // meal_log_ingredients both point at it.
        $this->addSql(<<<'SQL'
            CREATE TABLE ingredients (
                id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                name_en     text,
                name_ru     text,
                fodmap_tier text NOT NULL DEFAULT 'unknown'
                            CHECK (fodmap_tier IN ('low', 'moderate', 'high', 'unknown')),
                notes_en    text,
                notes_ru    text,
                created_at  timestamptz NOT NULL DEFAULT now()
            )
            SQL);

        // Per-user display preferences. In the reference this extends
        // auth.users via an FK on the primary key; here the id is simply the
        // application's user identifier.
        $this->addSql(<<<'SQL'
            CREATE TABLE profiles (
                id           uuid PRIMARY KEY,
                display_name text,
                created_at   timestamptz NOT NULL DEFAULT now()
            )
            SQL);

        $this->addSql(<<<'SQL'
            CREATE TABLE recipes (
                id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id     uuid NOT NULL,
                name        text NOT NULL,
                description text,
                servings    int NOT NULL DEFAULT 2,
                created_at  timestamptz NOT NULL DEFAULT now()
            )
            SQL);

        // ingredient_name, fodmap_tier and fodmap_ingredient_id were dropped by
        // reference migration 026 — the row's tier is read through ingredient_id.
        $this->addSql(<<<'SQL'
            CREATE TABLE recipe_ingredients (
                id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                recipe_id     uuid NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
                amount        numeric,
                unit          text,
                ingredient_id uuid REFERENCES ingredients(id) ON DELETE SET NULL
            )
            SQL);

        // day_of_week: 0 = Monday … 6 = Sunday. is_leftover and
        // leftover_source_id come from reference migration 013.
        $this->addSql(<<<'SQL'
            CREATE TABLE meal_plans (
                id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id            uuid NOT NULL,
                week_start         date NOT NULL,
                day_of_week        int NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
                meal_type          text NOT NULL
                                   CHECK (meal_type IN ('breakfast', 'lunch', 'dinner')),
                recipe_id          uuid REFERENCES recipes(id) ON DELETE SET NULL,
                created_at         timestamptz NOT NULL DEFAULT now(),
                is_leftover        boolean NOT NULL DEFAULT false,
                leftover_source_id uuid REFERENCES meal_plans(id) ON DELETE SET NULL,
                CONSTRAINT meal_plans_user_week_day_meal_unique
                    UNIQUE (user_id, week_start, day_of_week, meal_type)
            )
            SQL);

        $this->addSql(<<<'SQL'
            CREATE TABLE meal_logs (
                id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id    uuid NOT NULL,
                date       date NOT NULL,
                meal_type  text NOT NULL
                           CHECK (meal_type IN ('breakfast', 'lunch', 'dinner')),
                notes      text,
                created_at timestamptz NOT NULL DEFAULT now(),
                CONSTRAINT meal_logs_user_date_meal_unique UNIQUE (user_id, date, meal_type)
            )
            SQL);

        // ingredient_name and fodmap_tier were dropped by reference migration 026.
        $this->addSql(<<<'SQL'
            CREATE TABLE meal_log_ingredients (
                id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                meal_log_id   uuid NOT NULL REFERENCES meal_logs(id) ON DELETE CASCADE,
                ingredient_id uuid REFERENCES ingredients(id) ON DELETE SET NULL
            )
            SQL);

        // weight_kg was made nullable and notes added by reference migration 009 —
        // an entry may be a journal note with no weight.
        $this->addSql(<<<'SQL'
            CREATE TABLE weight_logs (
                id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id   uuid NOT NULL,
                weight_kg numeric,
                logged_at timestamptz NOT NULL DEFAULT now(),
                notes     text
            )
            SQL);

        // tag holds a user_tags id as text (reference migration 016 replaced the
        // original string keys with UUIDs, leaving the column type unchanged).
        $this->addSql(<<<'SQL'
            CREATE TABLE day_tags (
                id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id    uuid NOT NULL,
                date       date NOT NULL,
                tag        text NOT NULL,
                notes      text,
                created_at timestamptz DEFAULT now()
            )
            SQL);

        // Multiple tags per day are allowed; the same tag twice on one day is not.
        $this->addSql('CREATE UNIQUE INDEX day_tags_user_date_tag ON day_tags (user_id, date, tag)');

        $this->addSql(<<<'SQL'
            CREATE TABLE shopping_checks (
                id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id         uuid NOT NULL,
                for_date        date NOT NULL,
                ingredient_name text NOT NULL,
                checked         boolean NOT NULL DEFAULT true,
                created_at      timestamptz NOT NULL DEFAULT now(),
                CONSTRAINT shopping_checks_user_date_ingredient_unique
                    UNIQUE (user_id, for_date, ingredient_name)
            )
            SQL);

        // tag_type holds a user_tags id as text, same as day_tags.tag.
        // goal is 'increase' | 'decrease' | 'maintain'; reminder_days is the
        // 'maintain' nudge threshold, persisted but not yet wired to anything.
        $this->addSql(<<<'SQL'
            CREATE TABLE tag_settings (
                id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id       uuid NOT NULL,
                tag_type      text NOT NULL,
                enabled       boolean NOT NULL DEFAULT true,
                goal          text NOT NULL DEFAULT 'maintain',
                reminder_days integer,
                created_at    timestamptz DEFAULT now(),
                CONSTRAINT tag_settings_user_tag_unique UNIQUE (user_id, tag_type)
            )
            SQL);

        // builtin_key marks a row seeded from one of the formerly hardcoded tags
        // ('alcohol' | 'workout' | 'intimacy'); NULL for a user's own tag.
        $this->addSql(<<<'SQL'
            CREATE TABLE user_tags (
                id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
                user_id     uuid NOT NULL,
                name        text NOT NULL,
                emoji       text NOT NULL DEFAULT '🏷️',
                builtin_key text DEFAULT NULL,
                created_at  timestamptz DEFAULT now()
            )
            SQL);
    }

    public function down(Schema $schema): void
    {
        // Reverse creation order so no foreign key outlives the table it targets.
        $this->addSql('DROP TABLE user_tags');
        $this->addSql('DROP TABLE tag_settings');
        $this->addSql('DROP TABLE shopping_checks');
        $this->addSql('DROP TABLE day_tags');
        $this->addSql('DROP TABLE weight_logs');
        $this->addSql('DROP TABLE meal_log_ingredients');
        $this->addSql('DROP TABLE meal_logs');
        $this->addSql('DROP TABLE meal_plans');
        $this->addSql('DROP TABLE recipe_ingredients');
        $this->addSql('DROP TABLE recipes');
        $this->addSql('DROP TABLE profiles');
        $this->addSql('DROP TABLE ingredients');
    }
}
