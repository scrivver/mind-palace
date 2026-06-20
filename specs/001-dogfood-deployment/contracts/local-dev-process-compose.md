# Contract: Local Development Process Compose

## Scope

The root local dogfood path provides one command that starts the complete Mind
Palace environment after the developer enters the root Nix shell.

## Commands

### `dev`

**Purpose**: Start the full local dogfood stack.

**Preconditions**:
- Current working directory is the repository root.
- Developer has entered `nix develop`.
- Submodules are initialized.

**Behavior**:
- Starts a root full-stack process-compose configuration.
- Includes shared infrastructure, Reliquary API and thumbnail worker, Engram API
  and ingestion worker, Synapse worker/reconciler as applicable, Caddy proxy,
  Authentik, and the primary app entry point.
- Provides process status and logs through process-compose.
- Does not require a separate `start-infra` invocation.

**Success signals**:
- Process-compose reports required services as running or healthy.
- The public proxy health endpoint responds.
- User-facing app entry point can connect to Reliquary and Engram routes.

**Failure signals**:
- Failed service name is visible in process-compose status.
- Service logs identify missing configuration, port conflicts, or dependency
  failures.

### `start-infra`

**Purpose**: Start only shared infrastructure for targeted debugging.

**Behavior**:
- Remains available but is not the default dogfood startup path.
- Uses the infra-only process-compose configuration.

### `shutdown-infra` or replacement shutdown command

**Purpose**: Stop the active process-compose stack.

**Behavior**:
- Stops managed processes without deleting `.data/`.
- Documents how to reset `.data/` separately.

## Required Service Groups

- `postgres`: local database socket and databases for Authentik, Engram, and
  Synapse.
- `rabbitmq`: queues `engram.ingest`, `reliquary.thumbnail`,
  `reliquary.thumbnail.dead`, and `synapse.jobs`.
- `minio`: buckets for Reliquary, Engram, and Synapse local storage.
- `authentik`: local identity provider and Mind Palace OAuth application.
- `caddy`: public local proxy and storage route.
- `reliquary-api`: storage API and canonical event producer.
- `reliquary-thumbnail-worker`: durable thumbnail consumer.
- `engram-api`: read-only metadata API.
- `engram-ingestion`: metadata extraction worker.
- `synapse-worker`: movement worker.
- `synapse-reconciler`: reconciliation publisher when enabled for dogfood.
- `app`: primary Mind Palace user interface.

## State Contract

- Reusable runtime state lives under `.data/`.
- Generated process-compose YAML lives under `.data/`.
- Reset requires an explicit documented command and must not happen as part of
  normal shutdown.

## Reporting Contract

Dogfood failure reports for local dev must include:
- deployment path: `local-dev`
- state freshness: fresh or reused
- process-compose status snapshot
- failed service name if known
- sanitized log excerpt
- command used to start and stop the environment
