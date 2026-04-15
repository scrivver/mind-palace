# Mind Palace Monorepo

## Project Overview
`mind-palace` is a digitalized mnemonic technique system. It is structured as a monorepo containing multiple storage and metadata backends, Flutter applications, and a unified Nix-managed infrastructure layer.

### Core Components
1.  **Reliquary (`/reliquary`)**: Digital Cold Storage system.
    - **Backend**: Go API server using MinIO for object storage.
    - **Frontend**: Flutter application for artifact management and analytics.
2.  **Engram (`/engram`)**: Metadata extraction and search layer.
    - **Ingestion**: Python worker that extracts metadata from MinIO events.
    - **API**: Go server providing read-only access to extracted metadata.
3.  **Synapse (`/synapse`)**: Reconciliation-driven file movement engine.
    - **Worker**: Go process that transfers files between storage tiers.
4.  **Mind Palace App (`/app`)**: Primary user-facing Flutter application.

## Infrastructure (Root `/infra`)
The project uses a unified infrastructure managed via Nix flakes and `process-compose`.

- **PostgreSQL**: Shared database for Authentik, Engram, and Synapse.
- **RabbitMQ**: Shared message broker.
  - `engram.ingest`: Receives S3 bucket notifications from MinIO.
  - `synapse.jobs`: Receives movement tasks.
- **MinIO**: Shared object storage. Configured to emit AMQP events to RabbitMQ on `reliquary` bucket changes.
- **Caddy**: Unified reverse proxy (port 2080).
  - `/api/reliquary/*` -> Reliquary Backend.
  - `/api/engram/*` -> Engram Backend.
  - `/storage/*` -> MinIO.
- **Authentik**: Shared identity provider for OIDC/OAuth2.

## Development Workflow

### Prerequisites
- [Nix](https://nixos.org/) with flakes enabled.
- [tmux](https://github.com/tmux/tmux) (required for the `dev` launcher).

### Commands
```bash
# Enter the unified development shell
nix develop

# Start the entire system (Infrastructure + all Backends + Frontend)
dev

# Individual service management
start-infra      # Starts PostgreSQL, RabbitMQ, MinIO, Caddy, Authentik
source load-infra-env # Loads dynamic ports into current shell
shutdown-infra   # Stops all managed services
```

## Architecture & Conventions
- **Event-Driven**: Reliquary storage events flow through MinIO -> RabbitMQ -> Engram Ingestion.
- **Nix-First**: All environments and build processes are managed via Nix flakes at the root.
- **Submodules**: `reliquary`, `engram`, and `synapse` are integrated as git submodules but share the root infrastructure during development.

## Key Files
- `flake.nix`: Root environment and infrastructure orchestration.
- `infra/`: Nix definitions for shared services.
- `bin/dev`: Multi-service tmux launcher.
- `reliquary/CLAUDE.md`, `engram/CLAUDE.md`, `synapse/CLAUDE.md`: Component-specific guides.
