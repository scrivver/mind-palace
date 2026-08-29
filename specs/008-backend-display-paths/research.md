# Research: Backend Display Paths

## Decision: Reuse `filename` as the display path contract

**Rationale**: Engram already has a `files.filename` column and JSON `filename` field. The problem is semantic correctness, not missing schema. Using `filename` for user-facing relative display path avoids schema churn and allows the Flutter gallery to derive folders from an existing field.

**Alternatives considered**:

- Add a new `display_path` field: rejected for this fix because it requires schema/API/model changes and migration decisions while `filename` already carries the intended user-facing concept.
- Use `file_path` in the frontend: rejected because it is storage identity with owner/date prefixes and is not stable UI semantics.

## Decision: Keep `file_path` as storage identity only

**Rationale**: Engram idempotency and storage lookup depend on `(storage_type, file_path)`. That contract should not change. The fix must not alter object keys or delete/download identity.

**Alternatives considered**:

- Change storage key format to match user folders: rejected because it affects object storage, thumbnails, delete behavior, and existing data.
- Derive display paths by stripping known storage prefixes in Engram: rejected as fragile; Reliquary already knows the upload-relative path at event production time.

## Decision: Fix Reliquary event production first

**Rationale**: Reliquary is the canonical producer for S3 file events. It receives the relative upload `path` before creating the storage key, so it has the best source of truth for the display path.

**Alternatives considered**:

- Repair in Engram ingestion from `file_path`: rejected because Engram cannot reliably distinguish user folders from storage layout.
- Repair only in Flutter: rejected because all clients would have to duplicate storage-key heuristics.

## Decision: No automatic backfill in this feature

**Rationale**: Existing rows may have only basename filenames. Backfill would require deciding whether storage key segments after year/month are always user paths and would risk corrupting non-Reliquary or legacy data.

**Alternatives considered**:

- Backfill all existing rows from `file_path`: rejected as unsafe.
- Backfill only Reliquary rows with `files/<owner>/<yyyy>/<mm>/...`: deferred to a separate migration feature if needed.
