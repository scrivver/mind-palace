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

## Compose Service Contract

The default Compose deployment must:
- expose only the public ingress or app entry point by default
- keep PostgreSQL, RabbitMQ, MinIO, and Authentik on the internal network
- use health checks or dependency conditions for critical services
- use named volumes for persistent state
- include one-shot initialization services for buckets, queues, or identity
  bootstrap when needed
- avoid bind-mounting source code into application containers

## Environment Contract

`.env.example` must document:
- public port and base URL
- MinIO root credentials and buckets
- RabbitMQ queues and connection defaults
- PostgreSQL database names/users used by bundled services
- Authentik bootstrap credentials and OAuth client settings
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
