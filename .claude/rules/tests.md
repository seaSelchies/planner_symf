---
paths:
  - "tests/**"
---

# Test conventions

Rules for `tests/**` only. They are scoped here because they do not transfer: banning mocking frameworks says nothing about `src/`, where nobody mocks, and the other half — implement the port yourself and keep its state in memory — would read as permission to fake persistence in production code, where a port implementation must be a real adapter under `Infrastructure/` doing real IO.

1. **Never use a mocking framework.** `createMock()`, `createStub()`, `getMockBuilder()`, `createPartialMock()`, and `prophesize()` are forbidden in every test in this repo.
2. **Substitute a hand-written fake for each port the unit under test needs** — a real class implementing the Domain interface, passed in through the constructor (`InMemoryUserProvider implements UserProvider`, `FakePasswordHasher implements PasswordHasher`).
3. **Fake naming is fixed:** `InMemory*` for a fake that stores state (repositories, providers), `Fake*` for a stateless collaborator (hashers, clocks, mailers).
4. **A fake lives next to the test that uses it**, in the same folder and namespace (`tests/Auth/Application/Command/SignUp/`), one class per file, declared `final`.
5. **A fake exposes observations as query methods and never asserts:** counters like `isEmailSignedUpCalls(): int` and accessors like `createdUsers(): array` — no `self::assert*` and no throwing to signal a failed expectation inside a fake.
6. **Tests mirror the source layout module-first** — `tests/{Module}/{Layer}/...` with namespace `App\Tests\{Module}\{Layer}\...`, matching `src/{Module}/{Layer}/...`.
7. **Test classes are `final` and named `{Subject}Test`.**
8. **Assert on observable outcome, never on interaction order** — the returned Response DTO's fields and the fake's resulting state, not the sequence in which methods were called.
9. **Verify an expected Domain exception with `try`/`catch` plus `self::fail()`**, so the exception message and the collaborators' post-state are both asserted; a bare `expectException()` hides the second half.
10. **`Application` and `Domain` tests run with no database, no container, and no network** — they extend `PHPUnit\Framework\TestCase`, never `KernelTestCase`.
11. **Only tests under `tests/{Module}/Infrastructure/` may touch Doctrine, a connection, or a schema**, and they are integration tests against a real test Postgres.
12. **Time in a test comes from an injected fake clock with a fixed instant** — never `new DateTimeImmutable()` and never an assertion with a tolerance window.
