# urlshort

A small, production-shaped URL shortening service. Built as a technical
exercise: minimal in scope, but structured the way a real service should be
— tested, containerized, documented, and set up with CI from the start.

## Brief → how it's satisfied

The exercise asked for a simple app, production-shaped, handed off to
another engineer. Point by point:

| Requirement | Where |
|---|---|
| Built with AI-assisted development | [docs/AI_USAGE.md](docs/AI_USAGE.md) — built with Claude as pair-programmer; what it did, what was verified by hand before each commit |
| Git & GitHub with a proper workflow | Trunk-based, feature branch per change, `--no-ff` merges, Conventional Commits — see the commit history and [CONTRIBUTING.md](CONTRIBUTING.md) |
| Runs with Docker | `docker compose up --build` — see Quick start below |
| Automated testing | 15 tests (unit + API-level), 96% coverage, enforced in CI on every push/PR — see Running tests below |
| Documentation for the next engineer | This README, [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) (design decisions, trade-offs, known limitations), [infra/README.md](infra/README.md) (deployment), [CONTRIBUTING.md](CONTRIBUTING.md) (workflow) |
| No VPS/server provided — deployment approach is my call | Deployed to AWS ECS Fargate via Terraform + GitHub Actions, one click to stand up or tear down — see Deployment note below. Verified live, then destroyed to avoid ongoing cost (this was a timeboxed exercise, not a service anyone depends on) |

## Stack

- **Python 3.12 / FastAPI** — small surface area, automatic OpenAPI docs, easy to test.
- **SQLAlchemy 2.0** — ORM; SQLite for local dev, Postgres in Docker Compose (see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for why).
- **pytest** — unit + API tests, run against an isolated in-memory SQLite DB.
- **Docker / Docker Compose** — reproducible run, no local Python install required.
- **GitHub Actions** — lint, test, and Docker build/smoke-test on every push/PR.

## Quick start (Docker — recommended)

```bash
docker compose up --build
```

The API is now at `http://localhost:8000`. Interactive docs (Swagger UI) at
`http://localhost:8000/docs`.

```bash
# create a short link
curl -s -X POST http://localhost:8000/api/v1/links \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://en.wikipedia.org/wiki/Special:Random"}'

# → {"code":"aZ3kLQp","original_url":"...","short_url":"http://localhost:8000/aZ3kLQp","clicks":0,"created_at":"..."}

# follow it
curl -s -o /dev/null -w '%{http_code} -> %{redirect_url}\n' http://localhost:8000/aZ3kLQp

# check stats
curl -s http://localhost:8000/api/v1/links/aZ3kLQp
```

Tear down: `docker compose down -v` (the `-v` also drops the Postgres volume).

## Quick start (local Python, no Docker)

```bash
make install   # creates .venv and installs dependencies
make run       # starts uvicorn with --reload on http://localhost:8000
```

This uses a local SQLite file (`urlshort.db`) by default — see `.env.example`
for the environment variables you can override.

## Running tests

```bash
make test      # pytest, with coverage report
make lint      # ruff
```

Tests run against an isolated in-memory SQLite database (see
`tests/conftest.py`) and don't touch whatever `DATABASE_URL` you have
configured locally, so `make test` is always safe to run.

## API summary

| Method | Path                    | Description                                  |
|--------|--------------------------|-----------------------------------------------|
| POST   | `/api/v1/links`          | Create a short link (optionally with a custom code) |
| GET    | `/api/v1/links/{code}`   | Fetch stats for a link (does not redirect)   |
| DELETE | `/api/v1/links/{code}`   | Delete a link                                |
| GET    | `/{code}`                | Redirect to the original URL, increments clicks |
| GET    | `/healthz`               | Health check (used by Docker/orchestrator)   |

Full request/response schemas are in the auto-generated docs at `/docs`
once the app is running.

## Project layout

```
app/
  main.py        FastAPI routes
  crud.py        DB access, kept separate from HTTP concerns
  models.py      SQLAlchemy models
  schemas.py     Pydantic request/response models + validation
  database.py    Engine/session setup
  config.py      Settings (env-driven)
tests/           pytest suite (unit + API-level)
.github/         CI workflow, PR template
docs/            Architecture notes and decisions
```

## Documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — design decisions, trade-offs, and known limitations/next steps.
- [CONTRIBUTING.md](CONTRIBUTING.md) — git workflow, branching, commit conventions, how to open a PR.

## Deployment note

No hosting/VPS was provisioned for this exercise, so there's no long-lived
public deployment. To prove the Docker image is actually deployable (not
just "builds successfully in CI"), it was deployed end-to-end to **AWS ECS
Fargate** using the Terraform + GitHub Actions pipeline in
[infra/](infra/README.md) — dedicated VPC, ALB, ECR, OIDC auth (no static
AWS keys), one click to deploy or destroy from the Actions tab.

**Verified live** at `http://urlshort-alb-981073736.ap-southeast-1.elb.amazonaws.com`
on 2026-09-22 — health check, link creation, redirect, and click-count
tracking all confirmed working against the real AWS-hosted instance. The
stack was destroyed after verification (`Actions → Destroy AWS stack`) to
avoid leaving billable resources running, so that URL will 404/time out by
the time anyone else opens it. To stand it back up: `infra/README.md` has
the one-time bootstrap step; every deploy after that is a single workflow
trigger.
