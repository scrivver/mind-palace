# Mind Palace Next Steps

Production packaging and horizontal-scaling direction are defined separately in
`docs/reliquary-production-architecture.md`.

The durable thumbnail worker extraction is implemented in
`reliquary/docs/separate-thumbnail-worker-plan.md`. The split-container Compose
deployment is implemented in `reliquary/docs/split-container-deployment.md`.
The next scaling prerequisite is moving checksum and mutable user state to a
transactional store.

## Target Architecture

Use one canonical file-event contract and exactly one producer per storage path:

```text
Filesystem -> Engram fsnotify watcher -> engram.ingest
Reliquary S3 operation -> Reliquary event emitter -> engram.ingest
```

S3-compatible storage provides object storage only. Engram must not depend on native
S3/MinIO notifications. Synapse remains separate: it emits transfer-completion domain
events and is not a filesystem watcher.

## Phase 1: Stabilize the Event Contract

1. Document the canonical `FileEvent` schema in Engram, including required fields,
   event values, SHA-256 format, and S3 object-key semantics.
2. Add a shared JSON contract fixture and parser/consumer tests for canonical create,
   delete, and rename events.
3. Add a database migration that treats `(storage_type, file_path)` as storage
   identity. Keep hash and owner available for content deduplication, but do not use
   hash uniqueness as event idempotency.
4. Make Engram ingestion idempotent by storage type and file path. A repeated create
   must update or safely resume the existing record, not be discarded solely because
   its hash already exists. Repeated deletes must succeed.
5. Keep legacy MinIO notification parsing during migration.

**Gate:** duplicate canonical events produce one correct Engram record and can recover
from interrupted processing.

## Phase 2: Remove Reliquary Archival

Follow `reliquary/docs/remove-archival-plan.md`.

1. Add and run the one-time archive restoration command, resolving key conflicts.
2. Disable worker construction, scheduling, and manual archive routes.
3. Remove archive API methods, navigation, screen, and archive statistics.
4. Keep `backend/worker/archival.go` as dormant, unreferenced code.
5. Update Reliquary documentation and tests.

**Gate:** no startup or API path can move files out of `files/<user>/...`.

## Phase 3: Add Explicit Reliquary Events

Status: implemented.

Follow `reliquary/docs/explicit-storage-events-plan.md`.

1. Add an event package with the canonical model, interface, fake emitter, and
   RabbitMQ implementation.
2. Use persistent messages, publisher confirms, and unroutable-message detection.
3. Emit `create` after successful uploads and duplicate-upload retries; emit `delete`
   after successful active-file deletion. Ignore thumbnails and internal metadata.
4. Configure RabbitMQ through environment variables and fail startup when required
   event delivery is unavailable.
5. Return a retryable error when storage succeeds but event confirmation fails.
   Document delivery as at least once.

**Gate:** Reliquary integration tests prove upload and delete flow through RabbitMQ
into Engram using only canonical messages.

## Phase 4: Infrastructure Cutover

Status: source configuration implemented; deployment smoke test remains.

Deploy Phase 1 before Phase 3. During one coordinated cutover:

1. Start the Reliquary backend with explicit publication enabled.
2. Remove `MINIO_NOTIFY_AMQP_*` settings and `mc event add` from root infrastructure.
3. Verify the Reliquary bucket has no notification target or event rule.
4. Update root Nix shells, launch scripts, health checks, and documentation.
5. Run upload/delete smoke tests and confirm exactly one event per operation.

Do not leave both producers enabled. Roll back both the backend emitter and MinIO
configuration together if the cutover fails.

## Phase 5: Cleanup

1. Remove Engram's legacy S3/MinIO notification parser after the migration window.
2. Update architecture documents to describe canonical events only.
3. Reuse the shared contract fixture in Reliquary emitter and Engram watcher tests to
   prevent schema drift.
4. Leave Synapse behavior unchanged; review its `MoveCompleted` reliability as a
   separate project.

## Verification Matrix

- Reliquary backend: `go test ./...`
- Reliquary frontend: `flutter analyze && flutter test`
- Engram watcher/backend: `go test ./...` in each Go module
- Engram ingestion: parser/handler tests plus `bin/test-ingest`
- Root: `nix flake check` and an end-to-end upload, search, and delete test
- Confirm restarts and duplicate deliveries do not create stale or duplicate metadata
