# AI-assisted development notes

This project was built with Claude as an AI pair-programmer, as required by
the exercise. Documenting this here rather than just claiming it in the
README so the process is auditable via the commit history.

## What AI did

- Generated the initial scaffold (FastAPI app structure, SQLAlchemy models,
  Pydantic schemas, CRUD layer) and the test suite.
- Wrote the Dockerfile, docker-compose.yml, and GitHub Actions CI workflow.
- Wrote the Terraform module + environment config + bootstrap stack in
  `infra/`, and the `deploy.yml`/`destroy.yml` CI/CD workflows.
- Drafted this documentation set (README, ARCHITECTURE, CONTRIBUTING, and
  the `infra/` docs).

## What actually broke, and how it got found

This wasn't a clean one-shot run — worth documenting honestly rather than
implying otherwise, since it's more useful to the next engineer than
pretending everything worked first try:

- **Dockerfile ran as non-root into a root-owned directory.** The default
  SQLite path wasn't writable by the non-root container user; the CI
  smoke-test container crashed silently. Found because the *first* version
  of that smoke-test script used `bash -e`, which killed the script before
  `docker logs` ever ran — so the real fix was two-part: make `/app`
  writable, and make the CI script actually surface container logs on
  failure instead of exiting blind.
- **OIDC trust policy didn't match GitHub's actual subject claim format.**
  Every visible piece of config (role ARN, provider ARN, audience) looked
  correct, and it still failed. The actual mismatch only showed up in
  CloudTrail's raw event JSON — GitHub now embeds immutable owner/repo IDs
  in the `sub` claim, not just `owner/repo`. See `infra/README.md`'s
  Troubleshooting section.
- **Region mismatch between the state bucket and the configured region.**
  An example command in `bootstrap/README.md` didn't make `-var="aws_region=..."`
  explicit enough, so it silently used a default that didn't match where
  the bucket actually got created. Fixed in the docs, not just the code.
- **First-ever ECS use in the AWS account needed a service-linked role**
  the CI role didn't have permission to create. One-time manual `aws iam
  create-service-linked-role` unblocked it; the policy now grants that
  permission so a fresh account self-heals.

None of these were caught by local testing (`pytest`/`ruff` all passed
throughout) — they only surfaced against the real GitHub Actions runner
and real AWS account, which is exactly the gap local tests can't cover.

## What was verified by hand before commit

- `ruff check` and the full `pytest` suite were run locally after every
  meaningful change to the application code.
- Every file was read end-to-end before being committed; nothing was
  committed unread.
- The infra changes above were verified against real CI runs and real
  AWS error messages (CloudTrail, not guesswork) before being called fixed
  — see the bullets above for specifics.

## Why this matters for the next engineer

If something in this codebase looks under-explained or over-engineered,
assume it's worth double-checking rather than trusting it blindly — that's
true of any code, but doubly true of AI-generated code that hasn't yet seen
production traffic, and doubly true again for infrastructure config, which
is much harder to unit-test than application code and tends to fail in
ways that only show up at actual deploy time (see above).
`docs/ARCHITECTURE.md` lists known limitations and what to revisit first.
