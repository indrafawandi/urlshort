# Contributing

## Branching model

Trunk-based, with short-lived feature branches:

- `main` is always deployable — CI must be green before merge, and merge
  is the only way to get code into `main` (no direct pushes).
- Branch per change, named `<type>/<short-description>`, e.g.
  `feat/custom-codes`, `fix/redirect-404`, `docs/architecture`.
- Rebase (or squash-merge) onto `main` rather than long-lived merge commits,
  to keep history readable.
- Delete the branch after merge.

This is intentionally simple (no `develop` branch, no release branches) —
appropriate for a small service with a single deployable artifact. If this
project grows multiple concurrently-supported versions, revisit.

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/): `<type>: <summary>`,
e.g. `feat: add custom short-code support`, `fix: return 404 for unknown code
on redirect`, `docs: document deployment plan`, `test: cover duplicate
custom-code conflict`, `chore: bump fastapi to 0.115.4`.

Why: it makes `git log` skimmable, and a changelog can be generated from it
later without extra process.

## Opening a pull request

1. Create a branch off `main`.
2. Make the change, with tests (`make test`) and lint (`make lint`) passing
   locally.
3. Open a PR against `main` — the template will prompt for what/why/how to
   test.
4. CI must pass (lint, tests, Docker build+smoke-test) before merge.
5. Squash-merge once approved.

## Code style

- `ruff` is the linter; run `make lint` before pushing. CI will otherwise
  fail the build on lint errors.
- Keep HTTP concerns (`app/main.py`) separate from data access
  (`app/crud.py`) — it's what makes `tests/test_crud.py` possible without
  spinning up the whole app, and it's the pattern to keep following as the
  service grows.
- New endpoints or behavior changes should come with both a test and a
  README/API-table update in the same PR.

## AI-assisted development

This project was built with AI pair-programming (Claude). That's fine to
continue — but review generated code the same way you'd review a human's:
read every line before committing, run the tests, and don't merge something
you can't explain in the PR description.
