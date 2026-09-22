# urlshort

A small, production-shaped URL shortening service. Built as a technical
exercise: minimal in scope, but structured the way a real service should be
— tested, containerized, documented, and set up with CI from the start.

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

A Terraform stack to deploy this to **AWS ECS Fargate** (dedicated VPC, ALB,
no RDS/NAT — sized for a short-lived demo, meant to be `terraform destroy`'d
afterward) lives in [infra/aws-ecs-fargate/](infra/aws-ecs-fargate/README.md).
