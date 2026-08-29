# Feature Specification: Backend Display Paths

**Feature Branch**: `008-backend-display-paths`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "Fix the backend issue where gallery folder browsing has to infer directories from storage `file_path`. Reliquary should send the correct user-facing filename/display path, not the storage filepath, and Engram should persist and return it so the frontend can group `docs/myfile.pdf` and `docs/myfile2.pdf` under folder `docs`."

## User Scenarios & Testing

### User Story 1 - Preserve Folder Upload Display Paths (Priority: P1)

As a user uploading a folder, I want the relative path I uploaded, such as `docs/myfile.pdf`, to be preserved as the file's display path so gallery folder browsing matches my original directory structure.

**Why this priority**: The current event data can collapse folder uploads to a basename or force the frontend to infer folders from storage keys. Storage keys include owner/date layout and are not user-facing.

**Independent Test**: Upload or simulate a Reliquary folder upload with relative path `docs/myfile.pdf`; verify the emitted file event has `filename: "docs/myfile.pdf"` and `file_path` remains the storage key.

**Acceptance Scenarios**:

1. **Given** Reliquary receives a folder upload with form field `path=docs/myfile.pdf`, **When** it emits the create event, **Then** `filename` is `docs/myfile.pdf`.
2. **Given** Reliquary stores the object under `files/alice/2026/07/docs/myfile.pdf`, **When** it emits the create event, **Then** `file_path` remains the storage key and is not used as the display path.
3. **Given** Reliquary receives a normal single-file upload with no relative path, **When** it emits the create event, **Then** `filename` remains the basename such as `myfile.pdf`.

---

### User Story 2 - Persist And Return Display Paths From Engram (Priority: P2)

As a gallery client, I want Engram to persist and return the user-facing filename/display path from the canonical file event so the Flutter gallery can derive folders without inspecting `file_path`.

**Why this priority**: Mind Palace gallery reads Engram metadata. Reliquary can emit correct event data, but the value must survive ingestion and be returned by `GET /api/files` and `GET /api/files/{id}`.

**Independent Test**: Ingest a create event with `filename=docs/myfile.pdf`; query Engram's file list/detail APIs and verify the JSON response contains `filename: "docs/myfile.pdf"` and unchanged `file_path`.

**Acceptance Scenarios**:

1. **Given** Engram ingestion receives `filename=docs/myfile.pdf`, **When** the file row is inserted or updated, **Then** the `files.filename` column stores `docs/myfile.pdf`.
2. **Given** a stored file has `filename=docs/myfile.pdf`, **When** `GET /api/files` returns it, **Then** the response includes `filename: "docs/myfile.pdf"`.
3. **Given** a stored file has `file_path=files/alice/2026/07/docs/myfile.pdf`, **When** Engram returns it, **Then** `file_path` remains available for storage/download identity but is not the display path contract.

---

### User Story 3 - Document The Display Path Contract (Priority: P3)

As a developer working across Reliquary, Engram, and the Flutter gallery, I want the filename/display-path contract documented so future backend changes do not regress folder browsing.

**Why this priority**: This is a cross-component event/API contract issue. The contract must distinguish storage identity from user-facing display path.

**Independent Test**: Review the contract docs and fixtures; confirm examples show `filename=docs/myfile.pdf` and `file_path=files/alice/.../docs/myfile.pdf`.

**Acceptance Scenarios**:

1. **Given** a developer reads the file-event contract, **When** they inspect `filename`, **Then** it is documented as the user-facing relative display path.
2. **Given** a developer reads the Engram API contract, **When** they inspect `file_path`, **Then** it is documented as storage identity, not UI grouping input.

### Edge Cases

- Folder paths with leading slashes, `.` segments, `..` segments, duplicate separators, or backslashes must be sanitized before becoming `filename`.
- Single-file uploads without folder path must continue to use sanitized basenames.
- Duplicate upload conflict suffixing must preserve the same display path semantics used for storage key naming.
- Delete events may continue using a basename for `filename` if Engram deletes by `(storage_type, file_path)`, but this must not affect create/update display path persistence.
- Existing rows that already have basename-only `filename` cannot be repaired without a migration or reingestion; this feature focuses on new/updated events unless tasks explicitly add a backfill.

## Requirements

### Functional Requirements

- **FR-001**: Reliquary create events MUST set `filename` to the sanitized relative upload path when the upload includes a folder-relative path.
- **FR-002**: Reliquary create events MUST keep `file_path` as the storage object key.
- **FR-003**: Reliquary normal single-file uploads MUST continue to emit a sanitized basename as `filename`.
- **FR-004**: Engram ingestion MUST persist the event `filename` value exactly as the user-facing display path after validation/sanitization upstream.
- **FR-005**: Engram `GET /api/files` and `GET /api/files/{id}` MUST return the persisted display path in the existing `filename` JSON field.
- **FR-006**: No frontend fallback to `file_path` should be required for newly ingested Reliquary folder uploads after this backend fix.
- **FR-007**: The file-event contract MUST document `filename` as display path and `file_path` as storage identity.
- **FR-008**: Verification MUST include focused Reliquary backend tests and Engram ingestion/API tests.

### Key Entities

- **FileEvent.filename**: User-facing sanitized relative display path, e.g. `docs/myfile.pdf`.
- **FileEvent.file_path**: Storage identity key, e.g. `files/alice/2026/07/docs/myfile.pdf`.
- **Engram File.filename**: Persisted display path returned to clients.
- **Engram File.file_path**: Persisted storage identity used with `storage_type`.

### Contracts & Integration Impact

- **Affected Components**: `reliquary/backend/`, `reliquary/contracts/file-events/`, `engram/ingestion/`, `engram/backend/`, `engram/contracts/file-events/`, and Spec Kit docs.
- **Contracts**: Canonical file-event semantics and Engram file API response semantics. No queue name, auth, or storage-key format changes.
- **State & Migrations**: No required schema migration because `files.filename` already exists. Existing rows may remain basename-only until reingested or updated.
- **Idempotency/Retry Behavior**: File identity remains `(storage_type, file_path)`, so duplicate delivery and retries update the same row while refreshing `filename`.
- **Secrets/Configuration**: No new secrets, credentials, environment variables, or `.data/` state.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Reliquary create event tests prove `filename=docs/myfile.pdf` for folder uploads.
- **SC-002**: Engram ingestion tests prove `filename=docs/myfile.pdf` is stored for create and rename/update paths where applicable.
- **SC-003**: Engram API tests prove list/detail responses return the display path in `filename` while retaining `file_path`.
- **SC-004**: Contract docs and fixtures distinguish display path from storage identity.

## Assumptions

- The existing `filename` column and JSON field are the right place to carry the user-facing display path; no new `display_path` field is needed for this fix.
- Reliquary's upload `path` form field is already the best source of folder-relative display path.
- The Flutter frontend can keep its temporary compatibility fallback until backend-produced data is reliable.
