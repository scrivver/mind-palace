# File Display Path Contract

## Purpose

Define the difference between user-facing display path and storage identity across Reliquary, Engram, and clients.

## File Event

Producer: Reliquary.

Consumer: Engram ingestion worker.

Example create event:

```json
{
  "event": "create",
  "file_path": "files/alice/2026/07/docs/myfile.pdf",
  "filename": "docs/myfile.pdf",
  "size": 204800,
  "hash": "sha256:abcdef123456",
  "mtime": "2026-07-12T12:00:00Z",
  "device_name": "reliquary",
  "storage_type": "s3"
}
```

### Semantics

- `filename` is the user-facing sanitized display path.
- `file_path` is the storage identity key.
- Identity and idempotency are still `(storage_type, file_path)`.
- Clients must not derive user folders from `file_path`.

## Engram API

Affected endpoints:

- `GET /api/files`
- `GET /api/files/{id}`

Response excerpt:

```json
{
  "filename": "docs/myfile.pdf",
  "file_path": "files/alice/2026/07/docs/myfile.pdf"
}
```

### Semantics

- `filename` is safe for gallery display and folder grouping.
- `file_path` remains available for storage/download identity and should be treated as implementation detail by UI.

## Compatibility

- Existing basename-only filenames remain valid display paths.
- No schema migration is required.
- Historical rows are not automatically corrected by this feature.

## Implementation Notes

- Reliquary passes the final sanitized relative upload name into create-event
  publication. If collision handling appends a suffix to the stored relative
  name, `filename` follows that final display path.
- Engram validates and persists canonical event `filename` verbatim, including
  relative folders such as `docs/myfile.pdf`.
- Engram list/detail APIs scan and encode the persisted `files.filename` field
  unchanged; `file_path` remains present for storage identity.
