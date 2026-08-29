---
paths:
  - "src/**/Application/**/*.php"
---

# Application layer conventions

Layer-specific detail for CQRS use-case classes under `src/{Module}/Application/`. The repo-wide invariants in `AGENTS.md` also apply here; the rules below add what is specific to this layer and are not repeated there.

1. **A handler orchestrates, it never implements a business rule.** No `if` on a business condition inside a handler — the decision belongs in a Domain class (`SignUpValidator`) and reaches the handler as a thrown Domain exception.
2. **A handler never catches a Domain exception to turn it into a return value or an error string** — it lets the exception propagate to the Adapter, which is the only layer that maps it to a transport-level status.
3. **A handler never throws an HTTP- or framework-flavoured exception** (`HttpException`, `NotFoundHttpException`, `BadRequestException`) — Application code has no vocabulary for transport concerns.
4. **The handler class name matches its Command/Query name exactly** — `SignUpCommand` → `SignUpHandler`, `IsEmailSignedUpQuery` → `IsEmailSignedUpHandler` — so the pair is greppable by one token.
5. **A use case never calls another use case's handler.** Shared work moves down into a Domain service or port; handlers do not chain.

## Command use case — two classes, handler returns `void`

```php
// src/Auth/Application/Command/SignUp/SignUpCommand.php
final class SignUpCommand implements Command
{
    public function __construct(
        public readonly string $email,
        public readonly string $password,
        public readonly string $name,
    ) {
    }
}

// src/Auth/Application/Command/SignUp/SignUpHandler.php
final class SignUpHandler implements CommandHandler
{
    public function __construct(
        private readonly UserProvider $provider,
        private readonly UserRepository $repository,
        private readonly SignUpValidator $validator,
        private readonly PasswordHasher $hasher,
    ) {
    }

    public function __invoke(SignUpCommand $command): void
    {
        $this->validator->validate($command->email, $command->password, $command->name);

        if ($this->provider->isEmailSignedUp($command->email)) {
            throw new EmailAlreadyUsedException($command->email);
        }

        $user = (new User())->setEmail($command->email)->setName($command->name);
        $user->setPasswordHash($this->hasher->hash($user, $command->password));

        $this->repository->create($user);
    }
}
```

## Query use case — three classes, handler returns a Response DTO

```php
// src/Auth/Application/Query/IsEmailSignedUp/IsEmailSignedUpQuery.php
final class IsEmailSignedUpQuery implements Query
{
    public function __construct(
        public readonly string $email,
    ) {
    }
}

// src/Auth/Application/Query/IsEmailSignedUp/IsEmailSignedUpHandler.php
final class IsEmailSignedUpHandler implements QueryHandler
{
    public function __construct(
        private readonly UserProvider $provider,
    ) {
    }

    public function __invoke(IsEmailSignedUpQuery $query): IsEmailSignedUpResponse
    {
        return $this->provider->isEmailSignedUp($query->email)
            ? IsEmailSignedUpResponse::used()
            : IsEmailSignedUpResponse::free();
    }
}

// src/Auth/Application/Query/IsEmailSignedUp/IsEmailSignedUpResponse.php
final class IsEmailSignedUpResponse implements Response
{
    private function __construct(
        public readonly bool $isSignedUp,
    ) {
    }

    public static function used(): self
    {
        return new self(true);
    }

    public static function free(): self
    {
        return new self(false);
    }
}
```
