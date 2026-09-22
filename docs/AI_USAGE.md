# AI-assisted development notes

This project was built with Claude as an AI pair-programmer, as required by
the exercise. Documenting this here rather than just claiming it in the
README so the process is auditable via the commit history.

## What AI did

- Generated the initial scaffold (FastAPI app structure, SQLAlchemy models,
  Pydantic schemas, CRUD layer).
- Wrote the test suite (`tests/`) alongside the implementation.
- Wrote the Dockerfile, docker-compose.yml, and GitHub Actions CI workflow.
- Drafted this documentation set (README, ARCHITECTURE, CONTRIBUTING).

## What was verified by hand before commit

- `ruff check` and the full `pytest` suite were run locally after every
  meaningful change (see commit history — each functional commit corresponds
  to a passing local test run).
- Every file was read end-to-end before being committed; nothing was
  committed unread.
- The Docker/CI configuration is standard, boring, and easy to verify by
  reading it — deliberately avoided cleverness that would be hard for a
  reviewer (human or AI) to check.

## Why this matters for the next engineer

If something in this codebase looks under-explained or over-engineered,
assume it's worth double-checking rather than trusting it blindly — that's
true of any code, but doubly true of AI-generated code that hasn't yet seen
production traffic. `docs/ARCHITECTURE.md` lists known limitations and
what to revisit first.
