# Dogfood Deployment

Mind Palace supports two dogfooding paths:

- **Local development**: `nix develop`, then `dev`. This starts the full stack
  through root process-compose.
- **Packaged Compose**: `nix develop`, `./bin/deploy`, `cp .env.example .env`,
  edit secrets, then `docker compose up -d`.

The Compose path is a single-host dogfood deployment for smoke testing and
feedback. It is not a production horizontal-scaling guarantee.

## Local Development Dogfood

```bash
nix develop
dev
```

The `dev` command starts `.data/dev-process-compose.yaml` and uses
`.data/process-compose.sock`. It starts shared infrastructure, Reliquary,
Engram, Synapse, Caddy, Authentik, and the primary app entry point. A separate
`start-infra` invocation is not required.

Use infra-only startup for targeted debugging:

```bash
start-infra
```

Load dynamic ports and URLs in another shell:

```bash
source load-infra-env
```

Inspect status and logs:

```bash
process-compose process list -u "$PC_SOCKET"
process-compose process logs -u "$PC_SOCKET" caddy
```

Stop the active stack without deleting reusable state:

```bash
shutdown-infra
```

Reset local state only when a clean dogfood environment is intended:

```bash
rm -rf .data/
```

## Packaged Compose Dogfood

Build and load local images:

```bash
nix develop
./bin/deploy
```

Prepare configuration:

```bash
cp .env.example .env
$EDITOR .env
```

Values containing `change-me-in-shared-use` are placeholders. Replace them
before sharing or exposing the deployment.

Start, inspect, and stop:

```bash
docker compose up -d
docker compose ps
docker compose logs --tail=200
docker compose down
```

Podman users can use `podman compose` with the same arguments.

Reset packaged state only when intended:

```bash
docker compose down -v
```

## Service Boundaries

Only `ingress` publishes a host port by default. PostgreSQL, RabbitMQ, MinIO,
Reliquary, Engram, and Synapse services stay on the internal Compose network.

| Service | Image | Role |
|---------|-------|------|
| `ingress` | `mind-palace-ingress:latest` | Public HTTP entry point |
| `app` | `mind-palace-app:latest` | Primary app placeholder target |
| `reliquary-api` | `mind-palace-reliquary-api:latest` | Storage API and file-event producer |
| `reliquary-thumbnail-worker` | `mind-palace-reliquary-thumbnail-worker:latest` | Thumbnail worker |
| `engram-api` | `mind-palace-engram-api:latest` | Metadata API |
| `engram-ingestion` | `mind-palace-engram-ingestion:latest` | Metadata ingestion worker |
| `synapse-worker` | `mind-palace-synapse-worker:latest` | Transfer worker |
| `synapse-reconciler` | `mind-palace-synapse-reconciler:latest` | Reconciliation publisher |

## Dogfood Smoke Checklist

Run this checklist against both local development and packaged Compose paths:

1. Start the deployment path.
2. Confirm service status shows required services running or healthy.
3. Open the public entry point.
4. Authenticate or use the documented local access mode.
5. Add a small artifact.
6. Confirm the artifact is visible through the storage workflow.
7. Confirm metadata becomes discoverable through Engram.
8. Confirm movement or reconciliation behavior when Synapse is enabled.
9. Stop the deployment path.

## Known Differences

| Area | Local development | Packaged Compose |
|------|-------------------|------------------|
| Process manager | Root process-compose | Docker or Podman Compose |
| Runtime state | `.data/` | Named Compose volumes |
| App process | Live Flutter app command | Packaged image target |
| Service internals | Source checkout and hot reload where available | Image-based services |
| Reset | `rm -rf .data/` | `docker compose down -v` |

## Failure Report Template

```text
Deployment path: local-dev | packaged-compose
State freshness: fresh | reused | migrated | unknown
Failed step:
Failed service:
Status snapshot:
Sanitized log excerpt:
Configuration source: shell env | .env | generated config
Reset attempted: yes | no
Notes:
```

Do not include credentials, generated tokens, `.env` secret values, or full
database/object-storage contents in reports.
