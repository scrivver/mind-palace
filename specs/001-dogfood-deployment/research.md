# Research: Dogfood Deployment

## Decision: Root `dev` Starts the Full Stack with Process Compose

**Rationale**: Reliquary already proves the pattern: Nix generates an
infra-only process-compose file and a full-stack development process-compose
file. Root Mind Palace currently generates only infra process-compose and uses
tmux for app services after manual `start-infra`. Moving root `dev` to the
Reliquary-style full-stack process-compose config satisfies the one-command
dogfooding requirement and keeps service health, logs, and restarts in one
status UI.

**Alternatives considered**:
- Keep tmux and make `dev` call `start-infra` first. This reduces churn but does
  not provide unified health/status and keeps two orchestration models.
- Use Docker Compose for local development. This would slow iteration and
  duplicate Nix dev-shell behavior before packaged deployment is ready.

## Decision: Keep `start-infra` as an Infra-Only Debugging Path

**Rationale**: The feature requires one-command dogfooding, not removal of
manual debugging tools. Keeping `start-infra` allows targeted infrastructure
debugging and preserves existing workflows, while `dev` becomes the default full
environment path.

**Alternatives considered**:
- Remove `start-infra`. This would simplify the command surface but make
  component-level debugging harder.
- Rename all commands. This would create avoidable migration noise.

## Decision: Build a Root Split-Container Deployment Patterned After Reliquary

**Rationale**: Reliquary already has split images, `.env.example`,
`docker-compose.yml`, and `bin/deploy`. Mind Palace should follow the same user
experience at root: build/load images with Nix, copy/edit `.env.example`, then
start Compose. The root deployment should expose one public entry point and keep
PostgreSQL, RabbitMQ, MinIO, and Authentik internal by default.

**Alternatives considered**:
- Ship a single all-in-one container first. This would be compact but would not
  reflect the target service boundaries enough for dogfooding.
- Depend on published images only. This blocks local dogfooding when image
  publishing has not been configured.

## Decision: Replace Placeholder Engram/Synapse Images with Child-Owned Nix Build Jobs

**Rationale**: The current root package targets for Engram and Synapse are only
dogfood placeholders. Compose cannot validate the packaged deployment while
those images sleep instead of running application code. Reliquary's model is the
correct precedent: the component repo owns the Nix package and image outputs for
its own runtime boundaries, while the platform deployment consumes those outputs.
Engram and Synapse therefore need first-class package/image outputs in their own
flakes. Mind Palace should build those child outputs, load the image archives,
and tag or map them to the platform image names used by root Compose.

**Alternatives considered**:
- Keep placeholder containers until later. This leaves the packaged deployment
  unable to dogfood metadata extraction or reconciliation.
- Build images with ad-hoc Dockerfiles. This breaks the Nix-first requirement
  and diverges from Reliquary's reproducible deployment pattern.
- Put all Engram/Synapse package definitions in the Mind Palace root. This makes
  the platform repo know too much about component internals and creates package
  drift away from the repos that own the source, dependencies, and entrypoints.
- Collapse Engram and Synapse into a single image. This obscures service
  boundaries and makes health checks, scaling, and logs less useful.

## Decision: Package Engram as Separate API and Ingestion Runtime Images

**Rationale**: Engram has two deployable runtime boundaries: the Go read-only
API and the Python ingestion worker. The API should follow Reliquary's Go
pattern inside the Engram repo with a `buildGoModule` package and an API image
exposing port `8081` with an HTTP healthcheck at `/api/health`. The ingestion
worker should be a separate Engram-owned Python runtime image that includes the
locked Python dependencies, `libmagic`, OCR/PDF/media extraction tools required
by the worker, CA certificates, and an entrypoint equivalent to running the
ingestion worker from `engram/ingestion`.

**Alternatives considered**:
- Run `uv run main.py` in the final container. This is convenient but risks
  runtime network resolution and mutable dependency installation during Compose
  startup.
- Package the Go watcher for packaged dogfood now. Reliquary is the canonical
  S3 event producer in the root dogfood stack, so the watcher is not required
  for the initial packaged Compose deployment.
- Combine API and ingestion in one process. This conflicts with Engram's
  documented component boundary and makes worker restarts affect API reads.

## Decision: Package Synapse as One Go Package with Worker and Reconciler Images

**Rationale**: Synapse is a Go service with separate `cmd/synapse-worker` and
`cmd/synapse-reconciler` entrypoints. A single Synapse-owned Nix package can
build the Synapse command set, including `synapse-metagen` for setup/smoke
workflows, and two layered images can point their entrypoints at the worker and
reconciler binaries. This mirrors Reliquary's "one package, multiple images"
backend pattern without moving Synapse implementation knowledge into the
platform repo.

**Alternatives considered**:
- Build separate Go packages for each Synapse command. This is viable but
  duplicates module/vendor handling without a clear benefit.
- Use `go run` in containers. This is slower, requires source and toolchain in
  the image, and does not match the Reliquary packaging model.

## Decision: Compose Must Treat Image Build/Load as a Precondition

**Rationale**: Reliquary's Compose workflow intentionally separates image
build/load (`./bin/deploy`) from service startup (`docker compose up -d`).
Mind Palace should keep the same contract: `bin/deploy` builds and loads
component-owned image outputs from Reliquary, Engram, and Synapse, plus
root-owned app/ingress outputs, then Compose only runs already-loaded images.
This makes stale or missing images a documented failure mode before deployment
starts while preserving component packaging ownership.

**Alternatives considered**:
- Use Compose `build:` sections. This would mix Docker and Nix build systems and
  weaken reproducibility.
- Auto-run `bin/deploy` inside `docker compose up`. Compose does not provide a
  portable pre-build hook, and hiding image generation makes failures harder to
  debug.

## Decision: Compose Is Single-Host Dogfood, Not Production Scaling

**Rationale**: The feature asks for easy deployment and testing before
dogfooding. Existing docs already distinguish Reliquary's production direction
from single-host Compose. The root plan should make the same boundary explicit:
Compose verifies service packaging and user workflows; production scaling remains
future work.

**Alternatives considered**:
- Include Kubernetes manifests now. This expands scope beyond the dogfooding
  requirement and risks delaying local feedback.
- Treat Compose as production-ready. This would overstate guarantees around
  state, scaling, and secrets.

## Decision: Contracts Focus on Operational Interfaces

**Rationale**: This feature does not change end-user data models or public app
APIs. The important contracts are commands, service names, health endpoints,
environment variables, image names, volumes, and smoke-test report fields. These
must be stable enough for documentation and tasks to target.

**Alternatives considered**:
- Generate OpenAPI contracts. No new HTTP API is planned.
- Skip contracts because this is infrastructure work. That would miss the
  operational interfaces users rely on during dogfooding.

## Decision: No Application Contract Changes in Initial Plan

**Rationale**: Existing Reliquary canonical file events, Engram ingestion, and
Synapse job semantics are sufficient for dogfood smoke tests. Changing those
contracts would materially expand scope and require additional migration and
compatibility work.

**Alternatives considered**:
- Normalize event contracts as part of deployment. This is valuable but belongs
  to a separate feature unless a blocker appears during implementation.
