# Implementation Plan: Dogfood Deployment

**Branch**: `test-speckit` | **Date**: 2026-06-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-dogfood-deployment/spec.md`

## Summary

Deliver two dogfooding paths for the full Mind Palace system:

1. A single root `dev` command that starts shared infrastructure, Reliquary,
   Engram, Synapse, and the primary app under one process-compose session.
2. A Reliquary-style packaged deployment path with documented Docker Compose
   files, environment examples, Nix-built container images, and a smoke-test
   guide.

The implementation will reuse the existing root Nix shell and service modules,
replace the tmux-only root `dev` orchestration with a generated full-stack
process-compose config, and add split container build/deploy artifacts for the
Mind Palace service boundary.

## Technical Context

**Language/Version**: Nix flakes for orchestration and containers; Bash for
launcher scripts; Go services in Reliquary, Engram, and Synapse; Python 3.13
Engram ingestion via `uv`; Flutter/Dart primary app and Reliquary frontend.

**Primary Dependencies**: `process-compose`, PostgreSQL, RabbitMQ, MinIO,
Caddy, Authentik, Docker or Podman Compose, Nix build outputs, Flutter, Go,
Python `uv`.

**Storage**: Local dogfood uses `.data/` for PostgreSQL socket/data, RabbitMQ
state, MinIO buckets, Caddy config, Authentik state, and process-compose socket.
Packaged dogfood uses named Compose volumes for PostgreSQL, RabbitMQ, MinIO,
Authentik, and service-specific persistent state.

**Testing**: `process-compose` health/status checks, `curl` health probes,
component checks (`cd app && flutter analyze`, `cd app && flutter test`,
`cd reliquary/backend && go test ./...`, `cd engram && bin/test-ingest`,
Synapse build/test checks), and an end-to-end dogfood smoke checklist.

**Target Platform**: Linux development workstations with Nix flakes; local
single-host Docker or Podman Compose for packaged dogfooding.

**Project Type**: Nix-managed monorepo with root orchestration, Flutter app,
Go/Python services, and Git submodules for Reliquary, Engram, and Synapse.

**Performance Goals**: Full local dogfood startup reaches service-ready state
within 10 minutes on a prepared workstation. Packaged build/start/health/shutdown
workflow completes within 30 minutes after prerequisites are installed.

**Constraints**: One-command local startup after entering `nix develop`; internal
infrastructure services remain private in packaged Compose by default; generated
runtime state and secrets stay out of version control; existing file-event and
application data contracts remain compatible.

**Scale/Scope**: Single developer or maintainer dogfooding environment. Compose
deployment targets one host for smoke testing and feedback, not final horizontal
scaling.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: PASS. The plan uses the root `nix develop`
  environment, Nix-generated process-compose configs, and Nix package targets for
  container images. Verification commands are recorded in [quickstart.md](./quickstart.md).
- **Component boundaries**: PASS. Root orchestration owns `flake.nix`, `shells/`,
  `infra/`, `bin/`, Docker Compose, and root docs. Component README/agent
  guidance for `reliquary/`, `engram/`, and `synapse/` was reviewed. Component
  internals are only changed when required for packaged entrypoints or health
  checks, and those changes must stay in their submodules.
- **Contract-driven integration**: PASS. The affected contracts are startup,
  shutdown, service health, container image names, Compose configuration,
  environment variables, persistent state, and smoke-test reporting. Existing
  application APIs, file-event schemas, queue names, and storage identity remain
  unchanged unless implementation discovers an explicit blocker.
- **Verification proportional to change**: PASS. The plan requires process
  status checks, public health probes, packaged Compose health checks, component
  tests where touched, and an end-to-end dogfood smoke test.
- **State and secret hygiene**: PASS. Local state remains under `.data/`.
  Packaged state uses documented volumes. `.env.example` contains placeholders
  only, and documentation must identify secrets to replace before shared use.

Post-design re-check: PASS. Research, contracts, data model, and quickstart keep
the same boundaries and introduce no unreviewed constitution exceptions.

## Project Structure

### Documentation (this feature)

```text
specs/001-dogfood-deployment/
|-- plan.md
|-- research.md
|-- data-model.md
|-- quickstart.md
|-- contracts/
|   |-- local-dev-process-compose.md
|   `-- packaged-compose-deployment.md
`-- checklists/
    `-- requirements.md
```

### Source Code (repository root)

```text
flake.nix                    # Add full-stack dev process-compose and package targets
shells/
  infra.nix                  # Generate infra-only and full-stack process-compose configs
  dev.nix                    # Expose root dev shell tools and environment
infra/                       # Existing shared PostgreSQL/RabbitMQ/MinIO/Caddy/Auth
bin/
  dev                        # Start full process-compose stack
  start-infra                # Retain infra-only path for targeted debugging
  shutdown-infra             # Stop process-compose stack
  load-infra-env             # Export generated ports and service URLs
  deploy                     # Build/load split packaged images
docker-compose.yml           # Packaged dogfood deployment
.env.example                 # Packaged configuration placeholders
docs/
  dogfood-deployment.md      # User-facing local and packaged dogfood guide
reliquary/                   # Submodule: reused API, worker, frontend, container patterns
engram/                      # Submodule: API, watcher, ingestion, metadata contracts
synapse/                     # Submodule: worker/reconciler movement engine
app/                         # Primary Flutter client
```

**Structure Decision**: Implement root orchestration and documentation in the
root repository. Add submodule changes only when a component needs a packaged
binary, image, health check, or documented runtime command that it does not
currently expose.

## Complexity Tracking

No constitution violations are required.
