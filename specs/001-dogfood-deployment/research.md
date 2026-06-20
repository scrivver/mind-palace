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
