# Data Model: Backend Display Paths

## FileEvent

Canonical event message from Reliquary to Engram.

**Fields**

- `event`: `create`, `delete`, or future supported event type.
- `file_path`: Storage identity key, for example `files/alice/2026/07/docs/myfile.pdf`.
- `filename`: User-facing display path, for example `docs/myfile.pdf`.
- `storage_type`: Storage backend identity such as `s3`.
- `size`, `hash`, `mtime`, `device_name`: Existing metadata.

**Validation Rules**

- `filename` must be sanitized by Reliquary before event emission.
- `filename` must not contain leading slash, `..`, or empty path segments.
- `file_path` must remain unchanged for idempotency and storage identity.

## Engram File

Metadata row persisted by Engram.

**Fields**

- `filename`: Display path returned to API clients.
- `file_path`: Storage identity key, unique with `storage_type`.
- `storage_type`: Storage backend identity.
- Existing metadata: `id`, `size`, `hash`, `device_id`, `status`, `mime_type`, `page_count`, `mtime`, timestamps, tags.

**Relationships**

- One `FileEvent` create/upsert maps to one Engram `files` row by `(storage_type, file_path)`.
- `filename` updates on repeated create/rename-style messages for the same storage identity.

**State Transitions**

- Create event: insert row with event `filename`.
- Duplicate create delivery: update existing row and keep/refresh event `filename`.
- Delete event: delete row by `(storage_type, file_path)`.

## API File Response

Engram JSON response consumed by the Flutter gallery.

**Fields**

- `filename`: Display path; clients may derive folders from this value.
- `file_path`: Storage identity; clients should not use this for UI grouping.

**Validation Rules**

- `GET /api/files` and `GET /api/files/{id}` must return the same display-path semantics.
- Existing clients that use basename filenames still work because a basename is a valid display path.
