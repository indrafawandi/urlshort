# Architecture & Design Decisions

## Overview

```
                 ┌────────────┐
  client ──────▶ │  FastAPI   │──────▶ Postgres (docker-compose)
                 │  (app/)    │        or SQLite (local dev)
                 └────────────┘
```

A single stateless service backed by one relational table (`links`). No
queues, caches, or background workers — the problem doesn't need them yet,
and adding them speculatively would just be surface area for another
engineer to have to understand for no current benefit.

## Key decisions

**FastAPI + SQLAlchemy over a heavier framework.** The service is small
enough that a full framework (Django, etc.) would add more boilerplate than
value. FastAPI gives request validation (Pydantic), dependency injection for
the DB session, and OpenAPI docs for free — all things a "next engineer"
benefits from without extra docs to write.

**SQLite for dev/tests, Postgres for docker-compose.** Local dev and CI use
SQLite so nobody needs a running database just to `make test`. Docker
Compose runs Postgres because that's what an actual deployment would use —
running tests against SQLite while shipping Postgres is a known trade-off
(see "Known limitations" below); it was accepted here to keep the exercise
within scope.

**Tables created at startup (`Base.metadata.create_all`), not Alembic
migrations.** For one table with no schema history yet, a migration tool is
premature. This is explicitly called out as the first thing to change if the
schema needs to evolve — see "Next steps."

**Short codes: random, not sequential/hashed.** Codes are generated with
`secrets.choice` over an alphanumeric alphabet, checked for collision before
insert. This is simple and fine at this scale. A high-throughput production
version would likely move to a counter-based scheme (e.g. base62 of an
auto-increment ID) to avoid collision retries entirely.

**Click counting is synchronous, on the redirect path.** Every redirect does
a write. Fine at low/medium volume. At high volume this becomes a hot row
and should move to an async increment (e.g. batched writes, or a queue) —
see "Next steps."

**No auth.** Out of scope for the exercise; anyone can create/delete links.
A real deployment needs at minimum an API key or user-scoped links before
it's exposed publicly — see "Next steps."

## Testing strategy

- `tests/test_crud.py` — unit tests for pure logic (code generation)
  that don't need HTTP or even a full app.
- `tests/test_links.py` — API-level tests via FastAPI's `TestClient`,
  covering the actual contract (status codes, response shapes, error
  cases) rather than internal implementation.
- Each test function gets a fresh, isolated in-memory SQLite database
  (`tests/conftest.py`), so tests can run in any order with no shared
  state and no dependency on a running DB service.
- CI enforces a coverage floor (`--cov-fail-under=85`) so coverage doesn't
  silently erode over time.

## CI/CD

`.github/workflows/ci.yml` runs on every push and PR to `main`:
1. Lint (`ruff`) and test (`pytest` with coverage) — fails the build on
   either lint errors or a failing/under-covered test suite.
2. Build the Docker image and smoke-test it (`docker run` + hit `/healthz`)
   to catch "works on my machine, breaks in the image" issues before merge.

A separate CD pipeline (`.github/workflows/deploy.yml` /
`destroy.yml`, manually triggered) pushes the image to ECR and applies the
Terraform stack in `infra/` — see `infra/README.md`. This isn't wired to
run automatically on every merge to `main`: the target environment is a
short-lived demo stack meant to be spun up and torn down deliberately, not
a long-running environment that should redeploy on every commit. If this
becomes a real, continuously-running service, that's the one thing to
change — add `push: { branches: [main] }` to `deploy.yml`'s triggers.

## What was actually deployed (not just planned)

Unlike a typical take-home where "how this would be deployed" stays
hypothetical, this was actually built and run: AWS ECS Fargate, behind an
ALB, image pulled from ECR, provisioned by the Terraform module in
`infra/modules/ecs-fargate-app/` and deployed via GitHub Actions using
OIDC (no static AWS keys). Verified live once, then destroyed — see the
README's "Deployment note" for the confirmed-working URL and date, and
`infra/README.md` for how to stand it back up.

What that deployment deliberately leaves out, and would need adding before
this is a real, continuously-running production service:

1. Run Postgres as a managed service (RDS, Cloud SQL, etc.) rather than the
   demo's default SQLite-inside-the-container, which loses data on every
   task restart. (`docker-compose.yml`'s Postgres service is dev/demo-only
   too, for the same reason — see "Key decisions" above.)
2. Introduce Alembic for migrations before the first schema change ships;
   `Base.metadata.create_all` does not handle schema evolution.
3. HTTPS (ACM cert + domain) — the ALB is HTTP-only right now.
4. Structured logging and basic metrics (request count/latency, link
   creation rate) beyond the raw CloudWatch logs currently shipped.
5. Autoscaling — the ECS service runs a fixed `desired_count`, not hooked
   up to a scaling target.

## Known limitations / explicitly out of scope

- No authentication or rate limiting.
- No migrations (see above) — acceptable only because there is exactly one
  table and zero schema history so far.
- Click counting is a synchronous write per redirect (see above).
- No pagination/listing endpoint for links (`GET /api/v1/links` doesn't
  exist) — wasn't required by the exercise; trivial to add.
- Tests run against SQLite while Docker Compose runs Postgres. This is a
  reasonable trade-off at this size, but the next non-trivial change to
  `app/database.py` or any raw-SQL usage should also be tested against
  Postgres (e.g. via `docker compose` in CI) to be safe.
