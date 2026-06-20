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

Continuation scope: replace placeholder packaged images for Engram and Synapse
with real Nix-built containers owned by their respective child repositories.
Engram must publish package/image outputs for its Go API and Python ingestion
worker. Synapse must publish package/image outputs for its worker and
reconciler. Mind Palace consumes those child-repo outputs, tags or maps them to
the platform image names used by root Compose, and does not duplicate component
implementation build logic. The implementation should study and follow
Reliquary's `nix/backend.nix`, `nix/*-container.nix`, and `bin/deploy`
split-image pattern as the model for component-owned packaging.

## Technical Context

**Language/Version**: Nix flakes for orchestration and containers; Bash for
launcher scripts; Go services in Reliquary, Engram, and Synapse; Python 3.13
Engram ingestion via `uv`; Flutter/Dart primary app and Reliquary frontend.

**Primary Dependencies**: `process-compose`, PostgreSQL, RabbitMQ, MinIO,
Caddy, Authentik, Docker or Podman Compose, Nix build outputs, Flutter, Go,
Python `uv`, `pkgs.buildGoModule`, `pkgs.dockerTools.buildLayeredImage`,
`pkgs.python3Packages` or `uv`-materialized Python application packaging.

**Storage**: Local dogfood uses `.data/` for PostgreSQL socket/data, RabbitMQ
state, MinIO buckets, Caddy config, Authentik state, and process-compose socket.
Packaged dogfood uses named Compose volumes for PostgreSQL, RabbitMQ, MinIO,
Authentik, and service-specific persistent state.

**Testing**: `process-compose` health/status checks, `curl` health probes,
component checks (`cd app && flutter analyze`, `cd app && flutter test`,
`cd reliquary/backend && go test ./...`, `cd engram && bin/test-ingest`,
Synapse build/test checks), child-repo Nix package evaluation/builds for Engram
and Synapse container targets, root image load/tag checks, Compose configuration
validation, and an end-to-end dogfood smoke checklist.

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
  root-owned images. The continuation requires real Engram and Synapse package
  derivations in their own child repos instead of placeholder root containers.
  Verification commands are recorded in [quickstart.md](./quickstart.md).
- **Component boundaries**: PASS. Root orchestration owns `flake.nix`, `shells/`,
  `infra/`, `bin/`, Docker Compose, and root docs. Component README/agent
  guidance for `reliquary/`, `engram/`, and `synapse/` was reviewed. Component
  package outputs, image definitions, entrypoints, and healthcheck helpers belong
  in their submodules. Mind Palace consumes those outputs through stable flake
  contracts for orchestration. Reliquary's component-owned packaging pattern is
  used as precedent for Engram and Synapse.
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
flake.nix                    # Full-stack dev process-compose and root wrappers/aliases
nix/
  simple-container.nix       # Root-owned temporary/app/ingress helpers only
  ingress-container.nix
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
reliquary/                   # Submodule: owns Reliquary package/image outputs
engram/                      # Submodule: owns API and ingestion package/image outputs
  nix/
    backend.nix              # Build Engram Go API binary/package
    api-container.nix        # Build Engram API image
    ingestion.nix            # Build/materialize Python ingestion runtime
    ingestion-container.nix  # Build Engram ingestion image
synapse/                     # Submodule: owns worker/reconciler package/image outputs
  nix/
    synapse.nix              # Build Synapse Go command package
    worker-container.nix     # Build Synapse worker image
    reconciler-container.nix # Build Synapse reconciler image
app/                         # Primary Flutter client
```

**Structure Decision**: Implement root orchestration and documentation in the
root repository. Component-specific package outputs, image outputs, healthcheck
helpers, runtime entrypoints, and dependency materialization belong in the
component submodules. Mind Palace should consume the child repos through a small
orchestration contract: flake package names, image names, ports, health signals,
and environment variables.

Continuation packaging decision: Engram and Synapse must add their own Nix
package/image outputs first. The root `bin/deploy` then builds those child
flake outputs with `nix build path:$PROJECT_ROOT/engram#...` and
`nix build path:$PROJECT_ROOT/synapse#...`, loads the images, and tags them to
the `mind-palace-*` names expected by root Compose when needed. Root wrappers
must stay thin and must not duplicate component implementation packaging.

## Complexity Tracking

No constitution violations are required.
