# Mind Palace Monorepo

## Project Overview
`mind-palace` is a digitalized mnemonic technique system. It is structured as a monorepo containing a storage backend, multiple Flutter applications, and a Nix-managed infrastructure layer.

### Core Components
1.  **Reliquary (`/reliquary`)**: A "Digital Cold Storage" system for long-term preservation of artifacts.
    - **Backend (`/reliquary/backend`)**: Go API server (Chi router) using MinIO for object storage. Features include multi-user support, SHA-256 deduplication, JWT authentication, and automated lifecycle archival.
    - **Frontend (`/reliquary/frontend`)**: Flutter application (Web, Android, iOS, Linux) for managing artifacts, viewing galleries, and monitoring storage analytics.
2.  **Mind Palace App (`/app`)**: The primary Flutter application for the mnemonic system, likely serving as the user-facing interface that integrates with Reliquary for storage and Authentik for authentication.
3.  **Infrastructure (`/infra`, `/reliquary/infra`)**: Nix-based configuration for services including:
    - **MinIO**: Object storage.
    - **Caddy**: Reverse proxy and static file server.
    - **Authentik**: Identity provider for OIDC/OAuth2 support.

## Technologies
- **Languages**: Go (1.25+), Dart/Flutter (3.11+), Nix.
- **Backend**: Chi, MinIO Go SDK, JWT, FFmpeg (for video thumbnails).
- **Frontend**: Flutter (Dio, flutter_secure_storage, flutter_appauth).
- **Infrastructure**: Nix Flakes, `process-compose`, Docker/Podman (for deployment).

## Development Workflow

### Prerequisites
- [Nix](https://nixos.org/) with flakes enabled.
- [tmux](https://github.com/tmux/tmux) (recommended for the `dev` launcher).

### Commands
The project uses Nix development shells to manage dependencies and provides utility scripts in `bin/`.

```bash
# Enter the development shell
nix develop

# Start all services (Infrastructure, Backend, Frontend) in tmux
dev

# Individual service management (inside nix develop)
start-infra      # Starts MinIO, Caddy, and Authentik via process-compose
start-backend    # Starts Reliquary Go backend with hot reload (air)
start-frontend   # Starts Reliquary Flutter web server
shutdown-infra   # Stops all managed services
```

### Reliquary Specifics
- **Caddy Proxy**: Runs on `http://localhost:2080` by default.
  - `/api/*` -> Go Backend.
  - `/storage/*` -> MinIO.
- **Default Credentials**: `admin` / `admin` (Initial setup).

## Architecture & Conventions
- **Nix-First**: All development environments and build processes are managed via Nix flakes.
- **Process-Compose**: Used to orchestrate local infrastructure services.
- **Surgical Updates**: When modifying the backend or frontend, ensure compatibility with the reverse proxy configurations in `infra/`.
- **Deduplication**: Reliquary uses SHA-256 checksums for file deduplication; verify checksum logic when touching upload/storage paths.

## Key Files
- `flake.nix`: Root environment and infrastructure definitions.
- `reliquary/CLAUDE.md`: Detailed development guide for the Reliquary sub-project.
- `reliquary/backend/main.go`: Entry point for the Go storage server.
- `app/lib/main.dart`: Entry point for the main Mind Palace Flutter app.
