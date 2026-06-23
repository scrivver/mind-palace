# Contract: Packaged Compose Deployment

## Scope

The packaged dogfood path provides a Reliquary-style build-before-run workflow
for a single-host Mind Palace deployment.

## Required Files

- `docker-compose.yml`: default split-service dogfood deployment.
- `.env.example`: documented placeholders and safe local defaults.
- `bin/deploy`: builds Nix container outputs and loads them into Docker or
  Podman.
- `docs/dogfood-deployment.md`: local and packaged operation guide.
- Nix package targets for every local application image referenced by Compose.
- A real root-owned Mind Palace web app image served by Caddy, as specified in
  [app-web-compose.md](./app-web-compose.md).
- Engram-owned package/image outputs that build real API and ingestion runtime
  artifacts, not placeholder containers.
- Synapse-owned package/image outputs that build real worker and reconciler
  runtime artifacts, not placeholder containers.

## Image Contract

Image names must be stable and documented. Initial local image names:
- `mind-palace-app:latest`
- `mind-palace-reliquary-api:latest`
- `mind-palace-reliquary-thumbnail-worker:latest`
- `mind-palace-engram-api:latest`
- `mind-palace-engram-ingestion:latest`
- `mind-palace-synapse-worker:latest`
- `mind-palace-synapse-reconciler:latest`
- `mind-palace-ingress:latest`

If the implementation reuses Reliquary image names for component-local images,
the root docs must clearly map each Compose service to the image it expects.

## Build Job Contract

`bin/deploy` must build and load every local application image before Compose is
started. Mind Palace is the platform consumer: it stages a clean source copy,
invokes child-repo flake outputs from that copy, loads the resulting image
archives, and tags them to the root Compose image names when necessary.
Required build targets:

- `mind-palace-app-container`
- Reliquary-owned API image target, then tag or name it as
  `mind-palace-reliquary-api:latest`
- Reliquary-owned thumbnail worker image target, then tag or name it as
  `mind-palace-reliquary-thumbnail-worker:latest`
- Engram-owned API image target, then tag or name it as
  `mind-palace-engram-api:latest`. The child target is
  `engram#api-container`, producing `engram-api:latest`.
- Engram-owned ingestion image target, then tag or name it as
  `mind-palace-engram-ingestion:latest`. The child target is
  `engram#ingestion-container`, producing `engram-ingestion:latest`.
- Synapse-owned worker image target, then tag or name it as
  `mind-palace-synapse-worker:latest`. The child target is
  `synapse#worker-container`, producing `synapse-worker:latest`.
- Synapse-owned reconciler image target, then tag or name it as
  `mind-palace-synapse-reconciler:latest`. The child target is
  `synapse#reconciler-container`, producing `synapse-reconciler:latest`.
- `mind-palace-ingress-container`

Mind Palace app image requirements:

- entrypoint runs Caddy or an equivalent static web server
- serves the Nix-built Flutter web app
- exposes or participates in the single public Compose entry point
- proxies Reliquary and Engram API routes for same-origin browser access
- includes a healthcheck that verifies the web bundle is reachable
- does not run a Flutter dev server at runtime

Build targets must:

- be invokable from their owning repository with `nix build .#<target>`
- be invokable by the root deploy script with `nix build path:$PROJECT_ROOT/<component>#<target>`
- produce loadable OCI/Docker image archives
- embed application binaries or Python runtime artifacts produced by Nix
- avoid source-code bind mounts in Compose
- fail at build time, not runtime, when locked dependencies cannot be resolved
- expose a small contract to Mind Palace: target name, produced image name, main
  port if any, healthcheck command, and required environment variables

Engram API image requirements:

- entrypoint runs the Engram Go backend binary
- exposes port `8081`
- includes a healthcheck that probes `/api/health`
- accepts PostgreSQL and JWT/OIDC validation configuration from Compose environment

Engram ingestion image requirements:

- entrypoint runs the packaged Python ingestion worker
- includes required extraction runtime tools and CA certificates
- receives PostgreSQL, RabbitMQ, and S3 settings from Compose environment
- does not install Python dependencies during Compose startup

Synapse image requirements:

- worker image entrypoint runs `synapse-worker`
- reconciler image entrypoint runs `synapse-reconciler`
- both images are built from the same Synapse Go package when practical
- worker receives RabbitMQ and S3 settings from Compose environment
- reconciler receives RabbitMQ and Engram API settings from Compose environment
- `synapse-metagen` should be available from the package or a documented helper
  when needed for smoke-test setup

Mind Palace root requirements:

- root `bin/deploy` may tag child images to `mind-palace-*` names
- root `flake.nix` may expose thin aliases or wrapper targets only when useful
  for operator ergonomics
- root Nix files must not duplicate Engram or Synapse build implementation
  details such as Go module vendor hashes, Python dependency materialization, or
  component entrypoint construction
- root `bin/deploy` must produce a clear component-owner error if
  `engram#api-container`, `engram#ingestion-container`,
  `synapse#worker-container`, or `synapse#reconciler-container` is missing or
  renamed

## Compose Service Contract

The default Compose deployment must:
- expose only the public ingress or app entry point by default
- keep PostgreSQL, RabbitMQ, and MinIO on the internal network
- use health checks or dependency conditions for critical services
- use named volumes for persistent state
- include one-shot initialization services for buckets, queues, or identity
  bootstrap when needed
- avoid bind-mounting source code into application containers
- run real Engram and Synapse service images, not placeholder sleep containers
- run a real Mind Palace web UI image, not a placeholder sleep or text-response
  container

## Environment Contract

`.env.example` must document:
- public port and base URL
- MinIO root credentials and buckets
- RabbitMQ queues and connection defaults
- PostgreSQL database names/users used by bundled services
- shared JWT secret for Reliquary-issued tokens
- Reliquary password auth credentials (when password mode is enabled)
- optional OIDC issuer and client settings (when OIDC mode is enabled)
- application auth mode and secrets
- which values must be changed before shared or exposed use

Example secrets must be obvious placeholders and must not be suitable for shared
deployment.

## Operations Contract

Packaged dogfood documentation must include:
- build/load command
- copy/edit environment command
- startup command
- health/status command
- log inspection command
- smoke-test steps
- shutdown command
- reset-volume warning and command

## Reporting Contract

Dogfood failure reports for packaged Compose must include:
- deployment path: `packaged-compose`
- state freshness: fresh, reused, or migrated
- Compose status snapshot
- failed service name if known
- sanitized log excerpt
- `.env` source status without secret values
- image build/load timestamp or command output summary
