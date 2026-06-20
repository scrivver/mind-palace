# Reliquary Production Architecture Direction

## Purpose

This document defines the intended production direction for Reliquary. The current
all-in-one image remains useful for development, demos, and small single-host
installations, but it must not define the long-term service boundaries.

## Current Constraints

The default Compose deployment now separates Caddy ingress, the Go API, the
thumbnail worker, MinIO, and RabbitMQ. The all-in-one image remains available as
an optional compatibility deployment. Remaining production limitations include:

- Per-user checksum indexes use read-modify-write JSON objects in S3 and can lose
  concurrent updates across API replicas.
- User/account state stored as JSON in S3 has similar concurrency limitations.
- Infrastructure image versions and production resource limits still need to be
  managed by the deployment environment.

Placing multiple current API instances behind a load balancer is therefore not a
supported horizontal-scaling strategy.

## Target Production Topology

```text
Internet
   |
Ingress / TLS
   |
   +--> Flutter web container
   |
   +--> Reliquary API replicas
           |
           +--> S3-compatible object storage
           +--> PostgreSQL
           +--> RabbitMQ: reliquary.thumbnail
           +--> RabbitMQ: engram.ingest

RabbitMQ: reliquary.thumbnail
   |
Reliquary thumbnail worker replicas
   |
S3-compatible object storage
```

Production components should be independently deployable:

- **Ingress:** Caddy, nginx, Traefik, or Kubernetes Ingress for TLS and routing.
- **Frontend:** immutable Flutter web assets served by a small static web image.
- **API:** stateless Go service handling authentication, uploads, metadata, and
  explicit Engram event publication.
- **Thumbnail workers:** separate Go worker process consuming durable jobs.
- **Object storage:** external S3-compatible service with managed persistence.
- **RabbitMQ:** durable broker for thumbnail jobs and Engram file events.
- **PostgreSQL:** transactional application state and deduplication metadata.

## Required Application Changes

1. ~~Extract thumbnail execution into a dedicated worker binary and container.~~
2. ~~Replace the in-memory thumbnail channel with a durable
   `reliquary.thumbnail` queue using acknowledgements and bounded prefetch.~~
3. ~~Make thumbnail generation idempotent by destination object key.~~
4. Move checksum and upload identity records from S3 JSON indexes to PostgreSQL
   with appropriate unique constraints.
5. Move mutable user/account state to a transactional store, or delegate it fully
   to the configured identity provider.
6. Keep the API free of background work so replicas are interchangeable.
7. Add readiness checks for S3, PostgreSQL, and required RabbitMQ topology.

## Packaging Strategy

The repository provides separate application images:

- `reliquary-api`
- `reliquary-thumbnail-worker`
- `reliquary-ingress`

The API image should contain only the backend binaries, CA certificates, and
required runtime tools. The worker image may additionally contain ffmpeg and
Poppler. Neither image should embed MinIO, RabbitMQ, or an ingress server.

Retain an explicitly named `reliquary-all-in-one` image for convenience. It should
compose the same logical services but carry no production scaling guarantees.

## Delivery Sequence

1. Introduce separate image targets without changing runtime behavior.
   **Completed.**
2. Add the durable thumbnail queue and worker binary. **Completed.**
3. Migrate checksum and user state to PostgreSQL.
4. Make the API stateless and add replica-safe integration tests.
5. Add production Compose and Kubernetes manifests. **Compose completed;
   Kubernetes remains.**
6. Verify multiple API and worker replicas under concurrent upload, retry, and
   restart scenarios.

Horizontal API scaling is supported only after steps 2 through 4 are complete.
