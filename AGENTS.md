# AGENTS.md

Single authored rulebook for this repo. `CLAUDE.md` loads it with `@AGENTS.md`.
Path-scoped detail lives in `.claude/rules/` (`application-layer.md`, `tests.md`).

## Project

Pet project built to practice Backend PHP patterns.
PHP + Symfony, PostgreSQL as the database, Doctrine as the ORM/query layer.
Hexagonal Architecture (Ports & Adapters), organized module-first.

No domain module has landed on `main` yet — `Shared` holds the CQRS base and nothing else.
The invariants below illustrate their rules with classes from the `Auth` module, which lives on
the `feat/auth` branch; those names are examples, not files you will find here. The first module
to land follows the shape described below.

## Tech stack

- PHP `>=8.4`, Symfony `8.1.*` — **`composer.json` is authoritative.** If this file and
  `composer.json` ever disagree on a version, `composer.json` wins and this file is the defect.
- PostgreSQL, Doctrine ORM/DBAL, Symfony Messenger, PHPUnit, Composer.

## Architecture: module-first, four layers per module

```
config/                       # Symfony config
migrations/                   # Doctrine migrations (bundle default, project root)
public/index.php
src/
  Kernel.php
  {Module}/
    Adapter/                  # inbound adapters: HTTP controllers, DTO mapping
      Http/Controllers/
    Application/              # use cases, orchestration, CQRS handlers
      Command/{UseCase}/
      Query/{UseCase}/
    Domain/                   # pure business logic + ports; no framework deps
    Infrastructure/           # technical implementations of Domain ports
      DB/  Security/
  Shared/
    Domain/Bus/{Command,Query}/
    Infrastructure/Bus/{Command,Query}/
```

### Dependency rule (strict, inward-pointing)

`Adapter → Application → Domain ← Infrastructure`

- **Domain** depends on nothing else in the app. Plain PHP + ports, plus Doctrine mapping
  attributes on entities — that one framework exception is deliberate.
- **Application** depends only on `Domain`, through its interfaces.
- **Infrastructure** implements `Domain` ports and may use Doctrine/Symfony freely.
- **Adapter** depends on `Application` and is the only layer that knows the delivery mechanism.

`Domain` and `Application` must stay unit-testable with no database, no container and no
network. That is *why* every outbound dependency is a port rather than a direct call.

## CQRS base (`Shared`)

- Domain contracts: `src/Shared/Domain/Bus/Command/` (`Command`, `CommandHandler`, `CommandBus`)
  and `src/Shared/Domain/Bus/Query/` (`Query`, `QueryHandler`, `QueryBus`, `Response`).
  These are plain interfaces — no Symfony.
- Messenger implementations: `src/Shared/Infrastructure/Bus/Command/MessengerCommandBus.php`,
  `src/Shared/Infrastructure/Bus/Query/MessengerQueryBus.php`, plus `HandlerFailureUnwrapper`,
  which rethrows the original Domain exception out of Messenger's wrapper.
  `config/services.yaml` aliases each Domain bus interface to its Messenger implementation.
- Handler selection is by **marker interface**, not `#[AsMessageHandler]`: the `_instanceof`
  block in `config/services.yaml` tags every `CommandHandler` onto `command.bus` and every
  `QueryHandler` onto `query.bus`. The attribute would put Symfony inside `Application/`.
  A handler missing its marker is silently unroutable.

## Module rule

A new module reproduces the four-layer shape under its own `src/{NewModule}/` root and never
places classes inside another module's folder. It also registers its own Doctrine mapping
section in `config/packages/doctrine.yaml`, pointing at that module's `Domain` folder:

```yaml
doctrine:
    orm:
        mappings:
            {NewModule}:
                type: attribute
                is_bundle: false
                dir: '%kernel.project_dir%/src/{NewModule}/Domain'
                prefix: 'App\{NewModule}\Domain'
```

Tests mirror the same layout: `tests/{Module}/{Layer}/...`. See `.claude/rules/tests.md`.

## When a rule blocks the task

An invariant that prevents a correct solution is a bug in the invariant, not an obstacle to
route around. Stop and propose a wording change, citing the number. Never silently work around
a rule, and never edit an invariant on your own initiative. This has already happened once:
Messenger's `HandleTrait` violated invariant 34 as originally written, so the rule was narrowed
to permit a framework-provided trait under `Infrastructure/` or `Adapter/` — not bypassed.

# Invariants

Rules below are invariants, not preferences — violating any of them is a defect.
Review comments cite these numbers, so the numbering is fixed.

## Structure

1. Code is module-first then layer: `src/{Module}/{Adapter|Application|Domain|Infrastructure}/...`, e.g. `src/Auth/Application/Command/SignUp/SignUpHandler.php` — never layer-first with the module nested inside a layer folder.
2. A new module reproduces all four layer folders under its own `src/{Module}/` root and never places its classes inside another module's folder.
3. Dependencies point inward only (`Adapter → Application → Domain ← Infrastructure`), so no file under `Domain/` or `Application/` may contain a `use App\...\Infrastructure\` or `use App\...\Adapter\` import.
4. One class per file, filename identical to the class name, PSR-4 under the `App\` prefix mapped to `src/`. A Domain port is named for the role it plays and never carries an `I` prefix — `UserProvider`, not `IUserProvider`.

## Database and external services

5. Postgres is reached through Doctrine DBAL/ORM only, configured in `config/packages/doctrine.yaml` with `driver: pdo_pgsql` — no second persistence mechanism, no raw `PDO`, no third-party query builder.
6. Connection credentials come only from environment variables (`DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`) — never a hardcoded DSN, host, or password in PHP or YAML, and never a literal fallback inside `%env(...)%`.
7. Every schema change ships as a new migration file under `migrations/`, written with the DBAL `SchemaManager` API and guarded by an existence check, as in `migrations/Version20260722160749.php`.
8. An existing migration file is append-only: a wrong schema is corrected by adding a new migration, never by editing or deleting one that already exists.
9. Every outbound dependency (DB, hashing, mail, clock, HTTP) is declared as an interface in `src/{Module}/Domain/` and implemented under `Infrastructure/` — `SymfonyPasswordHasher implements PasswordHasher`, `Infrastructure\DB\UserRepository implements UserProvider, UserRepository`.
10. Read and write ports stay separate interfaces (`UserProvider` for reads, `UserRepository` for writes) and are never merged back into one interface.
11. `Domain` and `Application` code never references `EntityManager`, `Connection`, `QueryBuilder`, or a Doctrine repository class — persistence is reached exclusively through a Domain-defined port.

## Handlers, controllers, services

12. A command use case is one folder `src/{Module}/Application/Command/{UseCase}/` holding exactly `{UseCase}Command.php` and `{UseCase}Handler.php`; a query use case is `src/{Module}/Application/Query/{UseCase}/` holding `{UseCase}Query.php`, `{UseCase}Handler.php`, and `{UseCase}Response.php`.
13. Every use-case class carries its bus marker interface, on both sides and without exception: a command DTO implements `App\Shared\Domain\Bus\Command\Command` and its handler implements `App\Shared\Domain\Bus\Command\CommandHandler`; a query DTO implements `App\Shared\Domain\Bus\Query\Query`, its handler implements `App\Shared\Domain\Bus\Query\QueryHandler`, and its `{UseCase}Response` implements `App\Shared\Domain\Bus\Query\Response`. A Response DTO still exists on the query side only. The handler markers are what the `_instanceof` block in `config/services.yaml` tags onto `command.bus` and `query.bus`, so a missing one silently leaves the use case unroutable; the `Response` marker is what lets `QueryBus::ask(Query $query): Response` declare a real return type instead of `mixed` (invariant 23).
14. A handler exposes exactly one public method, `__invoke()`, and covers exactly one use case — no extra public methods, no second use case folded in.
15. A handler receives every collaborator as a `private readonly` constructor-injected Domain port and never builds one with `new` inside the class.
16. Classes in `Application/` and `Domain/` are declared `final` — handlers, Query/Command DTOs, Response DTOs, validators, and exceptions; the only exception is a Doctrine entity, which stays non-final so the ORM can proxy it.
17. Controllers live in `src/{Module}/Adapter/Http/Controllers/`, are named `Api{Action}Controller` for JSON endpoints, and declare their route with a `#[Route]` attribute on the action method.
18. A controller does not extend `AbstractController` and does not use its helpers: it constructs and returns a `Symfony\Component\HttpFoundation\JsonResponse` directly.
19. A controller reaches the Application layer by dispatching a command through `App\Shared\Domain\Bus\Command\CommandBus`, never by injecting or calling a concrete handler class.
20. A controller does only four things — read the request, build the Query/Command DTO, dispatch it, map the result or a caught Domain exception to an HTTP response — and contains no business rules, no validation, and no persistence.
21. Business rule-checking lives in a dedicated Domain class and reports failure by throwing a Domain exception — never by returning `null`, `false`, or an error string.
22. Current time is taken from an injected clock (`Symfony\Component\Clock\ClockInterface`), never from `new DateTimeImmutable()` or `time()` inside business logic.

## Return types and formats

23. Every method and function declares an explicit return type; an omitted return type and `mixed` are both rejected.
24. `CommandBus::dispatch(Command $command): void` — a command produces no payload, and a caller that needs the resulting state reads it afterwards through a query.
25. A command handler's `__invoke()` returns `void`; a query handler's `__invoke()` returns its own `{UseCase}Response` DTO — never an entity, an array, or a Symfony `Response`.
26. Query and Command DTOs and Response DTOs are immutable: constructor-promoted `public readonly` properties, no setters, and no behaviour beyond the constructor and named static factories.
27. A Response covering a fixed set of outcomes exposes named static factories over a `private` constructor (`IsEmailSignedUpResponse::used()` / `::free()`); a single unconditional shape uses a public constructor.
28. A controller that dispatched a command returns an empty-bodied `JsonResponse` — `201` for a created resource, `409` for a conflict, `400` for invalid input — and never invents a payload the command did not produce.
29. An error response body is `{"error": "<message>"}` carrying the Domain exception's message, with no stack trace and no internal class names.
30. A query controller returns a `JsonResponse` built from the Response DTO's public fields, and Domain ports return Domain types or `null` (`findByEmail(string $email): ?User`) — never Doctrine result arrays, `Query` objects, or Symfony types.

## Do not add

31. Do not add a Composer dependency for something Symfony 8.1 or Doctrine already provides — no second HTTP client, no alternative DI container, no ORM or query builder alongside Doctrine.
32. Do not add ORM access, HTTP classes, serializers, or Symfony service dependencies to `Domain` — the only framework code allowed there is Doctrine mapping attributes on entities.
33. Do not use `#[Route]`, form types, Twig, or `Request`/`Response` objects anywhere outside `Adapter/`.
34. Do not introduce Active Record, service locators, static registries, singletons, global helper functions, or a trait of our own that carries behaviour — collaboration happens through constructor-injected interfaces. A trait we write is banned in every layer, with no exception; a framework-provided trait (`Symfony\Component\Messenger\HandleTrait` and the like) is allowed only in a class under `Infrastructure/` or `Adapter/`, where framework coupling already lives, and never in `Domain/` or `Application/` (invariant 3). Behaviour two of our own classes share is extracted into a third class and constructor-injected into both, never lifted into a trait.
35. Do not create a catch-all `*Service` class in `Application/` — orchestration lives in a single-use-case handler.
36. Do not add setters or mutable state to a DTO, and do not reuse one DTO across two use cases.
37. Do not silence failures with `@`, an empty `catch`, or by downgrading a Domain exception to a `null` return.
38. Do not commit `.env`, `.env.local`, credentials, tokens, or dumps of real data.
