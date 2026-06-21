# Implementation Notes: Dogfood Deployment

## Phase 1 Setup Audit

- T001: Reviewed Engram packaging guidance in `engram/README.md` and
  `engram/CLAUDE.md`. Engram has separate Go backend API, Go filesystem
  watcher, and Python ingestion worker boundaries; packaged dogfood needs the
  API and ingestion worker images.
- T002: Reviewed Synapse packaging guidance in `synapse/README.md` and
  `synapse/CLAUDE.md`. Synapse has separate worker, reconciler, and metagen
  commands; packaged dogfood needs worker and reconciler images, with metagen
  available from the package.
- T003: Reliquary split-image precedent uses one Go package in
  `reliquary/nix/backend.nix`, image-specific `dockerTools.buildLayeredImage`
  files, API curl healthcheck, and worker PID liveness healthcheck.
- T004: Reliquary `bin/deploy` builds each flake image target, loads the
  archive into Docker or Podman, and treats Compose startup as a separate step.
  Mind Palace follows the same build/load-before-run model, plus root image
  tagging for child-owned images.
- T005: Root `flake.nix` currently owns placeholder targets for
  `mind-palace-engram-api-container`,
  `mind-palace-engram-ingestion-container`,
  `mind-palace-synapse-worker-container`, and
  `mind-palace-synapse-reconciler-container`. These must be removed or replaced
  by thin root consumption of child repo outputs.
- T006: Root `docker-compose.yml` references
  `mind-palace-engram-api:latest`,
  `mind-palace-engram-ingestion:latest`,
  `mind-palace-synapse-worker:latest`, and
  `mind-palace-synapse-reconciler:latest`. Root `bin/deploy` must build/load
  child images and tag them to these platform names.

## US1 Local Dogfood Preservation

- T017: `shells/infra.nix` still copies both infra-only
  `process-compose.yaml` and full-stack `dev-process-compose.yaml`, then exports
  `DEV_PROCESS_COMPOSE_FILE`.
- T018: `bin/dev` starts `process-compose` with `DEV_PROCESS_COMPOSE_FILE` and
  does not invoke or require `start-infra`.
- T019: root `flake.nix` still waits for Authentik OIDC discovery before
  starting the Engram API in the local full-stack process.
- T020: `infra/rabbitmq.nix` still uses a lightweight AMQP TCP readiness probe
  against the generated local port.
- T021: `nix eval --raw .#devShells.x86_64-linux.default.name` passed and
  returned `mind-palace-dev-shell`; `nix eval --raw
  .#devShells.x86_64-linux.infra.name` passed and returned
  `mind-palace-infra-shell`.
- T022: Generated `.data/dev-process-compose.yaml` parsed successfully with
  PyYAML and contains 17 processes including `engram-api`,
  `engram-ingestion`, `synapse-worker`, `synapse-reconciler`, and `app`.

## US2 Packaged Deployment

- T060: `nix eval --json path:./engram#packages.x86_64-linux --apply
  'builtins.attrNames'` passed with `["api-container","backend","default",
  "ingestion","ingestion-container"]`.
- T061: `nix eval --json path:./synapse#packages.x86_64-linux --apply
  'builtins.attrNames'` passed with `["default","reconciler-container",
  "synapse","worker-container"]`.
- T062: `nix build path:./engram#api-container --no-link --print-out-paths`
  passed and produced `/nix/store/ga8s75rvg7bw029gl1n77vkmnamqhkcz-engram-api.tar.gz`.
- T063: `nix build path:./engram#ingestion-container --no-link
  --print-out-paths` passed and produced
  `/nix/store/yfs8wmx2nl4kjbc203zq837ws665y8ak-engram-ingestion.tar.gz`.
- T064: `nix build path:./synapse#worker-container --no-link
  --print-out-paths` passed and produced
  `/nix/store/igahnqwr61vrq9dwd8inz5ysv5dh49v9-synapse-worker.tar.gz`.
- T065: `nix build path:./synapse#reconciler-container --no-link
  --print-out-paths` passed and produced
  `/nix/store/lkrsi2l0fh8rb3m194mybl07amz3g3sh-synapse-reconciler.tar.gz`.
- Root package output audit: `nix eval --json .#packages.x86_64-linux --apply
  'builtins.attrNames'` returned `["default","mind-palace-app-container",
  "mind-palace-ingress-container"]`, confirming Engram and Synapse image
  implementation targets are no longer root-owned placeholders.
- T066: `./bin/deploy` passed after switching the deploy script to build from a
  clean rsync staging tree that excludes `.data`, `.git`, `.dart_tool`, `build`,
  and `result*`. Docker loaded root, Reliquary, Engram, and Synapse images and
  tagged the child-owned images to the expected `mind-palace-*` names.
- T066 final re-run after submodule commits: `./bin/deploy` passed and loaded
  root, Reliquary, Engram, and Synapse images from the final tree.
- T067: `docker compose config --quiet` passed. `docker image ls` confirmed
  `mind-palace-engram-api:latest`, `mind-palace-engram-ingestion:latest`,
  `mind-palace-synapse-worker:latest`, and
  `mind-palace-synapse-reconciler:latest`.

## US3 Local vs Packaged Comparison

- T073: Known differences are documented in `docs/dogfood-deployment.md`:
  local dogfood uses root process-compose, `.data/`, source checkout processes,
  and hot reload where available; packaged dogfood uses Docker/Podman Compose,
  named volumes, and child-owned Engram/Synapse images. Failure reports now
  classify child packaging, root image tagging/loading, Compose wiring, runtime
  startup, and smoke-test workflow failures separately.

## Polish and Final Verification

- T074: `gofmt -w engram/backend/internal/config/config.go` completed.
  `TERM=xterm nix develop path:/home/chunhou/Dev/mind-palace/engram#backend -c
  go test ./...` passed. The final Engram API image rebuild passed after the
  PostgreSQL config change.
- T075: `TERM=xterm nix develop
  path:/home/chunhou/Dev/mind-palace/engram#ingestion -c ruff format main.py`
  reformatted the changed ingestion entrypoint, and `ruff check main.py`
  passed. A broader `ruff format --check main.py worker tests` reported
  pre-existing formatting drift in `worker/extractors.py`,
  `worker/pipeline.py`, and `worker/tagger.py`; those files were not changed for
  this feature.
- T076: `TERM=xterm nix develop path:/home/chunhou/Dev/mind-palace/synapse -c
  go test ./...` passed.
- T077: Root feature validation scripts passed:
  `dogfood-docs-contract.sh`, `env-example-contract.sh`,
  `local-dev-contract.sh`, and `packaged-compose-contract.sh`.
- T078: `git diff --check` passed.
- T079: `git status --short`, `git -C engram status --short`, and
  `git -C synapse status --short` show no generated runtime state, secrets,
  local database files, `.data/`, image archives, or `result*` symlinks in the
  final diff. Child repositories are clean after their commits.
- T080: Engram submodule packaging changes were committed as `cd18c01`
  (`packaging: add dogfood images`).
- T081: Synapse submodule packaging changes were committed as `aac8299`
  (`packaging: add dogfood images`).
- T082: Implementation summary: Engram and Synapse now own real child package
  and image outputs; root deploy builds from a clean staging tree, loads child
  images, tags them to Mind Palace Compose names, and Compose validation passes.
