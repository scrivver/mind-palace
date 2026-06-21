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

`./bin/deploy` builds the root-owned Flutter web app and ingress images, builds
Reliquary component images, then builds child-owned Engram and Synapse images:

| Owner | Child output | Loaded image | Root Compose tag |
|-------|--------------|--------------|------------------|
| Engram | `engram#api-container` | `engram-api:latest` | `mind-palace-engram-api:latest` |
| Engram | `engram#ingestion-container` | `engram-ingestion:latest` | `mind-palace-engram-ingestion:latest` |
| Synapse | `synapse#worker-container` | `synapse-worker:latest` | `mind-palace-synapse-worker:latest` |
| Synapse | `synapse#reconciler-container` | `synapse-reconciler:latest` | `mind-palace-synapse-reconciler:latest` |

You can validate child outputs directly when a component build fails:

```bash
nix build path:./engram#api-container --no-link --print-out-paths
nix build path:./engram#ingestion-container --no-link --print-out-paths
nix build path:./synapse#worker-container --no-link --print-out-paths
nix build path:./synapse#reconciler-container --no-link --print-out-paths
```

Prepare configuration:

```bash
cp .env.example .env
$EDITOR .env
```

Values containing `change-me-in-shared-use` are placeholders. Replace them
before sharing or exposing the deployment.

For browser dogfooding, `OIDC_REDIRECT_URI` should point at the public app
origin callback route, for example `http://localhost:2080/callback`.
Engram exposes the browser auth helper routes at:

```text
/api/engram/auth/config
/api/engram/auth/oidc/discovery
/api/engram/auth/oidc/token
```

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

PostgreSQL 18 expects its Docker volume at `/var/lib/postgresql`. If the
packaged stack was started with an older Compose file that mounted
`/var/lib/postgresql/data`, reset the named volumes before retrying:

```bash
docker compose down -v
docker compose up -d
```

## Service Boundaries

Only `app` publishes a host port by default. PostgreSQL, RabbitMQ, MinIO,
Reliquary, Engram, Synapse, and the retained ingress helper stay on the
internal Compose network.

| Service | Image | Role |
|---------|-------|------|
| `app` | `mind-palace-app:latest` | Public Flutter web UI and same-origin API proxy |
| `ingress` | `mind-palace-ingress:latest` | Internal legacy ingress helper |
| `reliquary-api` | `mind-palace-reliquary-api:latest` | Storage API and file-event producer |
| `reliquary-thumbnail-worker` | `mind-palace-reliquary-thumbnail-worker:latest` | Thumbnail worker |
| `engram-api` | `mind-palace-engram-api:latest` | Metadata API |
| `engram-ingestion` | `mind-palace-engram-ingestion:latest` | Metadata ingestion worker |
| `synapse-worker` | `mind-palace-synapse-worker:latest` | Transfer worker |
| `synapse-reconciler` | `mind-palace-synapse-reconciler:latest` | Reconciliation publisher |

Engram and Synapse package definitions, entrypoints, runtime tools, and
healthcheck helpers live in their child repositories. The root repository only
builds, loads, tags, and wires those images into Compose.

## Dogfood Smoke Checklist

Run this checklist against both local development and packaged Compose paths:

1. Start the deployment path.
2. Confirm service status shows required services running or healthy.
3. Open the public entry point.
4. Authenticate or use the documented local access mode.
5. For packaged web, confirm `GET /api/engram/auth/config` works through the
   same public origin before signing in.
6. Add a small artifact.
7. Confirm the artifact is visible through the storage workflow.
8. Confirm metadata becomes discoverable through Engram by checking the app
   metadata view or probing `GET /api/engram/health` and the documented metadata
   list/search route after ingestion has processed the artifact.
9. Confirm movement or reconciliation behavior when Synapse is enabled by
   checking `synapse-worker` and `synapse-reconciler` status, then verifying the
   expected hot/cold bucket state or reconciliation log after a tagged artifact
   is eligible to move.
10. Stop the deployment path.

## Known Differences

| Area | Local development | Packaged Compose |
|------|-------------------|------------------|
| Process manager | Root process-compose | Docker or Podman Compose |
| Runtime state | `.data/` | Named Compose volumes |
| App process | Live Flutter Linux desktop command | Nix-built Flutter web image served by Caddy |
| App routing | Generated absolute Reliquary and Engram URLs injected by `bin/start-app` | Same-origin `/api/reliquary/*` and `/api/engram/*` routes |
| Auth callback | Desktop loopback/AppAuth flow | Browser `/callback` flow using Engram OIDC helper endpoints |
| Service internals | Source checkout and hot reload where available | Image-based services |
| Engram packaging | Source checkout plus `uv run`/Go hot reload | Child-owned `engram#api-container` and `engram#ingestion-container` images |
| Synapse packaging | Source checkout plus Go commands | Child-owned `synapse#worker-container` and `synapse#reconciler-container` images |
| Reset | `rm -rf .data/` | `docker compose down -v` |

Expected differences should be reported as environment context, not product
defects. Unexpected differences in metadata discovery or reconciliation should
identify whether the failure category is child packaging, root image
tagging/loading, Compose wiring, web compile, Caddy proxy, Engram OIDC helper,
browser callback, or runtime startup.

## Troubleshooting

- **Child packaging**: A direct `nix build path:./engram#...` or
  `nix build path:./synapse#...` command fails. Check the child repo Nix file,
  dependency lock data, vendor hash, runtime tools, or entrypoint.
- **Root image tagging/loading**: Child builds pass but `./bin/deploy` fails to
  load or tag images. Check Docker/Podman availability and the source-to-root
  image mapping in `bin/deploy`.
- **Compose wiring**: `docker compose config --quiet` fails or services point at
  missing images/environment values. Check `docker-compose.yml` and `.env`.
- **Runtime startup**: Compose config is valid but a service is unhealthy or
  exits. Check `docker compose ps` and `docker compose logs --tail=200
  <service>`.
- **Packaged web UI**: `/` should return the Flutter shell, `/callback` should
  fall back to the same shell, and `/api/engram/auth/config` should return
  client-consumable JSON without secrets.

## Failure Report Template

```text
Deployment path: local-dev | packaged-compose
State freshness: fresh | reused | migrated | unknown
Failure category: child packaging | root image tagging/loading | Compose wiring | web compile | Caddy proxy | OIDC helper | browser callback | runtime startup | smoke test
Failed step:
Failed service:
Status snapshot:
Sanitized log excerpt:
Configuration source: shell env | .env | generated config
Image build/load summary:
Reset attempted: yes | no
Notes:
```

Do not include credentials, generated tokens, `.env` secret values, or full
database/object-storage contents in reports.
