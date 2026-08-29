# Feature Specification: Engram Folder Listing

**Feature Branch**: `009-engram-folder-listing`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "The /vault folder view builds its directory tree client-side from whatever page of files happens to be loaded, so the tree is incomplete and folders can render empty. Move directory listing into Engram, and stop the frontend from synthesizing folders out of storage keys."

## User Scenarios & Testing

### User Story 1 - Complete Folder Tree At Every Level (Priority: P1)

As a user browsing the vault in folder view, I want to see every folder that exists at the current level with an accurate file count, regardless of how many pages of files I have scrolled through.

**Why this priority**: This is the reported defect. The gallery derives folders from `state.files`, which holds only the pages fetched so far (50 per page, ordered by `created_at DESC`). Folders whose files have not been paged in do not exist as far as the UI is concerned, and entering a folder can show an empty directory that is not empty.

**Independent Test**: With more than one page of files spread across several folders, open folder view at the root without scrolling; verify every folder appears with a count matching the total number of files beneath it.

**Acceptance Scenarios**:

1. **Given** an owner has 120 files spread across 5 folders, **When** the gallery opens folder view at the root, **Then** all 5 folders are listed before any additional page is fetched.
2. **Given** a folder contains 80 files, **When** the user opens that folder, **Then** the first page of its files loads and scrolling fetches the rest.
3. **Given** a folder contains files nested two levels deep, **When** the folder is listed at the root, **Then** its count includes the nested files.
4. **Given** a type or tag filter is active, **When** folders are listed, **Then** the counts reflect only files matching that filter.

---

### User Story 2 - Search Still Flattens The Tree (Priority: P2)

As a user searching the vault, I want results from every folder in one flat list, exactly as before.

**Why this priority**: Search is the existing escape hatch from folder navigation. Folder scoping must not silently restrict search results.

**Independent Test**: Enter a search term while inside a folder; verify matching files from other folders appear and no folder rows are shown.

**Acceptance Scenarios**:

1. **Given** the user is inside `docs`, **When** they type a search query, **Then** results include matches outside `docs`.
2. **Given** a search is active, **When** the gallery renders, **Then** no folder rows are shown and each file displays its full display path.

---

### User Story 3 - Storage Keys Never Become Folders (Priority: P1)

As a user, I want the folder tree to reflect the directories I uploaded, never the internal storage layout.

**Why this priority**: `displayPathForFile` falls back to `file_path` when `filename` carries no directory, and its final branch returns the entire storage key. For a key that predates the `files/` prefix layout, such as `akadmin/2026/06/report.pdf`, this renders as a folder tree `akadmin > 2026 > 06`. This is a live, user-visible defect independent of any backend change.

**Independent Test**: Project a file whose `filename` is a bare basename and whose `file_path` does not match the current key layout; verify the display path is the basename and no folder is derived.

**Acceptance Scenarios**:

1. **Given** a file with `file_path=akadmin/2026/06/report.pdf` and `filename=report.pdf`, **When** the gallery projects it, **Then** the display path is `report.pdf`.
2. **Given** a file with `file_path=files/alice/2026/07/docs/report.pdf` and `filename=report.pdf`, **When** the gallery projects it, **Then** the display path is `docs/report.pdf`.
3. **Given** a file whose `filename` already contains a directory, **When** the gallery projects it, **Then** `filename` is used unchanged and `file_path` is never consulted.

---

### User Story 4 - Legacy Data Is Verified, Not Assumed (Priority: P3)

As an operator, I want a documented diagnostic that reports what row shapes exist, so a backfill is
written only if one is actually needed.

**Why this priority**: Three legacy shapes are conceivable, and a blind backfill would handle only
one of them. Running the diagnostic first showed this deployment has **none** of them: 20 rows, all
`status='ready'`, all current-layout keys, `legacy_layout=0` and `backfill_targets=0`. There is no
data to repair, so this feature ships no backfill. The diagnostic remains documented because the
answer differs per deployment and the question will recur.

**Independent Test**: Run the documented diagnostic against a populated database; verify it reports
a count for each legacy shape and that migration 005 modifies no rows.

**Acceptance Scenarios**:

1. **Given** the documented diagnostic, **When** an operator runs it before deploying, **Then** it
   reports counts for `legacy_layout`, `backfill_targets`, and `filename_is_key`.
2. **Given** migration 005, **When** it is applied, **Then** it creates an index and modifies no row
   data, and rolling it back drops only that index.
3. **Given** a deployment where the diagnostic reports `backfill_targets > 0`, **When** an operator
   consults the design docs, **Then** they find the deferred backfill SQL and its recorded side
   effect on the generated `tsv` column.


### Edge Cases

- Folder names containing `_` or `%` must not behave as SQL `LIKE` wildcards.
- Folder and path inputs with leading slashes, `.`, `..`, backslashes, or duplicate separators must be normalized identically on client and server.
- A path pointing at a directory with no files and no subfolders must return empty lists, not an error.
- Filters and search must apply identically to the folder query and the file query, so counts never disagree with contents.
- Files whose status is not `ready` remain excluded by default, unchanged from today. All 20 local rows are `ready`, so this is currently unobservable.
- The current dataset contains no folder uploads; folder view correctly showing a flat root is not a regression.

## Requirements

### Functional Requirements

- **FR-001**: Engram MUST expose a directory listing that returns every immediate subfolder of a given display-path prefix for the authenticated owner.
- **FR-002**: Each returned folder MUST carry a recursive count of files beneath it, matching the semantics the client previously computed.
- **FR-003**: `GET /api/files` MUST accept a directory scope that restricts results to files whose display path is a direct child of a given prefix.
- **FR-004**: Both endpoints MUST apply the existing `q`, `tag`, `type`, `from`, `to`, `status`, and `device` filters identically.
- **FR-005**: Existing callers of `GET /api/files` that send neither new parameter MUST observe unchanged behavior and response shape.
- **FR-006**: Prefix matching MUST escape SQL `LIKE` metacharacters so folder names containing `_` or `%` match literally.
- **FR-007**: Path normalization MUST reject or strip traversal segments and MUST agree with the client normalizer.
- **FR-008**: The gallery MUST render folders from the server response instead of deriving them from the loaded file page.
- **FR-009**: When a search query is active, the gallery MUST request unscoped results and render no folder rows.
- **FR-010**: The client display-path fallback MUST NOT return a storage key as a display path; when the key does not match a known layout it MUST return the basename.
- **FR-011**: Migration 005 MUST NOT modify row data. The local diagnostic reports zero repairable rows, so no backfill ships with this feature.
- **FR-012**: The repository MUST document the diagnostic query, the deferred backfill SQL, and the deferred handling of pre-restructure keys, so a future deployment with legacy data is not left to rediscover them.
- **FR-013**: Prefix queries MUST be served by an index that supports pattern matching under the deployment collation, and MUST remain correct if the database is created with a non-C collation.

### Key Entities

- **Folder**: A derived entity, not stored. `name` is the segment, `path` is the full display-path prefix, `file_count` is the recursive count of matching files beneath it.
- **File.filename**: The user-facing display path, established by feature 008. Sole input to folder grouping.
- **File.file_path**: Storage identity, `(storage_type, file_path)`. Never an input to folder grouping.

### Contracts & Integration Impact

- **Affected Components**: `engram/backend/`, `engram/backend/internal/db/migrations/`, `app/`.
- **Contracts**: Engram read-only HTTP API. The file-event contract is unchanged. No queue, storage key, or auth changes.
- **State & Migrations**: One migration adding an index. No row data is modified and the migration is fully reversible.
- **Idempotency/Retry Behavior**: Both endpoints are read-only. The migration is a single `CREATE INDEX`.
- **Secrets/Configuration**: None.

## Success Criteria

### Measurable Outcomes

- **SC-001**: With files spanning more than one page across multiple folders, the root folder view lists every folder before any additional page is fetched.
- **SC-002**: Folder counts equal the number of files beneath each folder under the active filter set.
- **SC-003**: Entering any listed folder yields at least one file, never an empty directory for a non-empty folder.
- **SC-004**: A file whose `file_path` does not match the current key layout renders as a basename at the root, producing no folder.
- **SC-005**: Requests to `GET /api/files` without the new parameters return byte-identical responses to the previous release, verified against the 20 existing rows.
- **SC-006**: A folder named with an underscore is reachable and lists only its own files.
