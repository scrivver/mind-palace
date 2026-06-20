# Implementation Notes: Dogfood Deployment

## Baseline Inspection

- Root `flake.nix` initially generated only `.data/process-compose.yaml` for
  shared infrastructure: PostgreSQL, RabbitMQ, MinIO, Caddy, and Authentik.
- Root `bin/start-infra` started the infra-only process-compose config.
- Root `bin/dev` initially required infrastructure to be running first and then
  launched Reliquary, Engram, Synapse, and the Flutter app in a tmux session.
- Root `bin/load-infra-env` exported dynamic local ports and service URLs after
  infrastructure wrote port files under `.data/`.
- Reliquary already provides the target pattern: Nix-generated infra-only and
  full-stack process-compose configs, `dev` as the full-stack process-compose
  entry point, `bin/deploy`, `.env.example`, and split Compose deployment docs.

## Reusable Reliquary Conventions

- Generate process-compose YAML with `pkgs.formats.yaml {}` at Nix evaluation
  time and copy it into `.data/` from the shell hook.
- Keep `start-infra` available for infrastructure-only debugging.
- Make `dev` start the full stack using process-compose and the same socket
  path as the infra-only workflow.
- Use a build-before-run packaged path: `nix develop`, `./bin/deploy`,
  `cp .env.example .env`, edit secrets, then `docker compose up -d`.
- Expose only a single ingress/public entry point in Compose by default.

## Component-Owned Image and Healthcheck Gaps

- Reliquary already owns split API, thumbnail worker, and web container targets.
- Engram currently has Go/Python development commands but no root-visible
  container image contract in this repository.
- Synapse currently has Go development commands but no root-visible container
  image contract in this repository.
- Root implementation therefore owns initial dogfood image wrappers and
  documents any follow-up need for component-owned image hardening.

## Validation Results

- `local-dev-contract.sh`: PASS after root full-stack process-compose generation
  and `bin/dev` conversion.
- `packaged-compose-contract.sh`: PASS after adding root `docker-compose.yml`.
- `env-example-contract.sh`: PASS after adding root `.env.example`.
- `dogfood-docs-contract.sh`: PASS after adding `docs/dogfood-deployment.md`.
- Shell syntax: PASS for root command scripts and feature validation scripts via
  `bash -n`.
- Compose syntax: PASS via `docker compose config --quiet`.
- Nix dev shell evaluation: PASS via
  `XDG_CACHE_HOME=/tmp/codex-cache nix eval --raw .#devShells.x86_64-linux.default.name`.
- Nix package target evaluation: PASS via
  `XDG_CACHE_HOME=/tmp/codex-cache nix eval --json .#packages.x86_64-linux --apply 'builtins.attrNames'`.
- Whitespace validation: PASS via `git diff --check`.
- Full `dev` runtime startup was not run because it would start long-running GUI
  and infrastructure processes in this session.
- Full image builds were not run; package target names were evaluated instead.
- Component test suites were not run because this change does not modify
  component-owned code inside `reliquary/`, `engram/`, or `synapse/`.
- Nix formatter was not run because no Nix formatter was available on PATH in
  the current shell; files were checked by Nix evaluation instead.

## Deferred Hardening

- Root placeholder images for `mind-palace-app`, Engram, and Synapse satisfy
  the initial dogfood image-name contract, but they are not production-grade
  component images. Component-owned container hardening remains follow-up work.
