# Mind Palace

A self-hosted personal digital archive — cold data storage, labeling, and retrieval with OAuth2 authentication.

Store artifacts (images, PDFs, any file), tag them, search metadata, and manage storage tiers. Designed for single-host dogfooding and small deployments today, with a path to horizontal scaling.

## Architecture

Mind Palace is split into three composable Go services plus a Flutter client:

| Component | Role | Stack |
|-----------|------|-------|
| **Reliquary** | Object storage API, file upload/download, thumbnail generation | Go, RabbitMQ, MinIO |
| **Engram** | Metadata catalog — indexing, search, ingestion from file events | Go, Python, PostgreSQL |
| **Synapse** | Storage-tier reconciliation and transfer worker | Go, RabbitMQ |
| **app** | Flutter web/desktop client | Flutter, Riverpod, go_router |

Shared infrastructure: PostgreSQL 18, RabbitMQ, MinIO, Caddy, Authentik (OIDC).

## Quickstart

### Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled
- Docker or Podman (for packaged Compose deployment)

### Local development

```bash
nix develop
dev
```

This starts the full stack — infrastructure, all three backends, and the Flutter Linux desktop client — through a root process-compose manager. State lives under `.data/`.

Use `start-infra` for infrastructure-only startup, then `source load-infra-env` to load dynamic ports, and `start-app` to launch the Flutter client separately for hot-reload workflows. Stop with `shutdown-infra`.

### Building the app container image

```bash
nix develop
./bin/update-pubspec-lock-json   # ensure pubspec.lock.json matches pubspec.lock
nix build .#mind-palace-app-container
docker load < result
```

The image bundles a Caddy server serving the compiled Flutter web assets on port 2080, with `/api/reliquary/*` and `/api/engram/*` reverse-proxied to backend services.

### Packaged Compose (dogfood)

Build all Docker images and start the full stack through Compose:

```bash
nix develop
./bin/deploy        # build and load all images
cp .env.example .env
$EDITOR .env        # set secrets (look for change-me-in-shared-use)
docker compose up -d
```

Open `http://localhost:2080` — you'll be prompted to sign in through the bundled Authentik instance. Add an artifact, confirm it appears, then `docker compose down` to stop.

### Reset state

| Path | Command |
|------|---------|
| Local dev | `rm -rf .data/` |
| Packaged Compose | `docker compose down -v` |

## Project layout

```
├── app/              Flutter client (Riverpod, go_router)
├── bin/              Entry-point scripts (dev, deploy, start-*)
├── docs/             Architecture, deployment, and roadmap docs
├── engram/           Metadata catalog (Go API + Python ingestion)
├── infra/            Nix-packaged shared infrastructure configs
├── reliquary/        Storage API and frontend (Go + Flutter)
├── shells/           Nix dev shells
├── specs/            Implementation specs by feature
└── synapse/          Reconciliation and transfer workers (Go)
```

Each child component (`reliquary/`, `engram/`, `synapse/`) is a Git submodule. Initialize with `git submodule update --init --recursive`.

## Documentation

- **`docs/dogfood-deployment.md`** — Full deployment guide with local-dev vs packaged-Compose comparison, smoke checklist, troubleshooting, and failure report template.
- **`docs/reliquary-production-architecture.md`** — Production scaling direction and target topology.
- **`docs/next-steps-plan.md`** — Roadmap: event contract stability, explicit Reliquary events, infrastructure cutover.
- **`specs/001-dogfood-deployment/`** — Deployment spec, tasks, and smoke testing.
- **`specs/002-sanctuary-health/`** — Service health status screen spec.
- **`specs/003-settings-page/`** — Theme and account settings spec.
- **`specs/004-frontend-refactoring/`** — Frontend refactoring (Riverpod DI, go_router, widget extraction) spec.
