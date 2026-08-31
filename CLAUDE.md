@AGENTS.md

# Commands

## Database

```bash
docker compose up -d database
```

The host port comes from `DATABASE_PORT` in `.env`, defaulting to 5432 — Compose reads the
same file Symfony does, so one value drives both the port mapping and Doctrine. Change it
there if 5432 is already taken; nothing else needs editing.

`DATABASE_HOST` / `DATABASE_PORT` / `DATABASE_USER` / `DATABASE_PASSWORD` / `DATABASE_NAME`
live in `.env`, which is untracked.

## Migrations

```bash
php bin/console doctrine:migrations:migrate
```

A new migration is expressed through the DBAL schema API, as in
`migrations/Version20260722160749.php`. Raw SQL via
`addSql()` is for a construct that API cannot express — a `CHECK` constraint, a partial or
expression index, an enum type, a data backfill — and the reason is named in a comment
directly above the call.
Do not use `doctrine:migrations:diff` — it emits SQL for everything, including what the
schema API does express, so its output is not the form invariant 7 requires.

## Tests

```bash
php bin/phpunit
```

## Run the app

```bash
symfony server:start -d
```

Without the Symfony CLI: `php -S localhost:8000 -t public/`.
