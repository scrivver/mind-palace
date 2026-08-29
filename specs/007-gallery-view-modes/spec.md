# Feature Specification: Gallery View Modes

**Feature Branch**: `007-gallery-view-modes`

**Created**: 2026-07-12

**Status**: Draft

**Input**: User description: "Improve the Mind Palace Flutter gallery with folder browsing based on file paths, a list view in addition to the existing grid, and an option to view all files with or without directory grouping. Implement this in two phases: first as a frontend UX improvement with scroll-down-to-load behavior over the existing API, then as a backend API improvement with cursor pagination and folder-aware browsing if needed."

## User Scenarios & Testing

### User Story 1 - Browse Files By Folder (Priority: P1)

As a user browsing the Mind Palace gallery, I want to see folders derived from existing file paths so I can navigate a familiar directory structure instead of only scanning one flat grid.

**Why this priority**: The current gallery loses important organization that already exists in stored paths. Folder browsing is the main missing experience and already has a proven frontend pattern in the Reliquary app.

**Independent Test**: Seed or upload files with nested paths, open the gallery in folder mode, navigate into a folder, go back to the parent, and verify only direct child folders/files are shown at each level.

**Acceptance Scenarios**:

1. **Given** files exist at `files/alice/2026/06/report.pdf` and `files/alice/photos/image.jpg`, **When** I open folder mode at the gallery root, **Then** I see folders `2026` and `photos` rather than every nested file as top-level items.
2. **Given** I am at folder `2026`, **When** I open folder `06`, **Then** files directly inside `2026/06` are shown and unrelated folders are hidden.
3. **Given** I am inside a nested folder, **When** I use the back/up control, **Then** the gallery returns to the parent folder and clears any invalid child selection state.

---

### User Story 2 - Switch Between Grid And List Views (Priority: P2)

As a user reviewing many files, I want to switch between the current thumbnail grid and a denser list view so I can choose between visual browsing and scanning metadata.

**Why this priority**: Grid view is good for media, but list view is better for documents, mixed folders, and repeated review workflows.

**Independent Test**: Toggle the gallery from grid to list and back while the same filters/search remain active. Verify the same folder/file set appears with different layout density.

**Acceptance Scenarios**:

1. **Given** the gallery is showing files in grid mode, **When** I select list mode, **Then** the gallery shows rows with file/folder name, size or item count, modified date where available, and path/type context.
2. **Given** the gallery is in list mode inside a folder, **When** I switch back to grid mode, **Then** I remain in the same folder and see the same logical items as cards.

---

### User Story 3 - View All Files With Or Without Directories (Priority: P3)

As a user, I want an option to see all matching files in a flat view with their directory location, or browse with directory grouping, so search and review workflows are not forced into one navigation model.

**Why this priority**: Some tasks need structure; others need a flat result set. The option should be lightweight and preserve the current "all files" behavior.

**Independent Test**: Toggle between folder mode and all-files mode with filters/search applied. Verify all-files mode shows matching files regardless of directory and folder mode returns to the current/root folder state.

**Acceptance Scenarios**:

1. **Given** files exist across multiple folders, **When** I enable all-files mode, **Then** all matching files are shown in one list/grid and each item exposes its directory context.
2. **Given** I am in all-files mode, **When** I switch to folder mode, **Then** folder grouping is restored without requiring a page refresh.
3. **Given** search text is active, **When** I view results, **Then** matching files can be found across directories without requiring manual folder traversal.

---

### User Story 4 - Continue Loading While Scrolling (Priority: P4)

As a user browsing a large gallery, I want more files to load automatically as I scroll down so I do not need to click page controls.

**Why this priority**: The existing gallery already uses a scroll listener to load more files. The improved views should preserve and make this behavior reliable instead of adding page buttons.

**Independent Test**: Use a dataset larger than one page, scroll near the bottom of the gallery in grid, list, folder, and all-files modes, and verify the next page loads without clicking a next-page control.

**Acceptance Scenarios**:

1. **Given** more matching files exist than the first loaded page, **When** I scroll near the bottom of the gallery, **Then** the next page loads automatically and a bottom loading indicator is shown.
2. **Given** no more matching files exist, **When** I reach the bottom, **Then** the gallery stops requesting more pages and does not show a misleading loading state.
3. **Given** I change search, filters, grouping, sort, or folder path, **When** the gallery refreshes, **Then** pagination resets to the first page for the new result set.

### Edge Cases

- Files whose `file_path` does not include the expected `files/<owner>/` prefix still appear under a safe display path rather than disappearing.
- Empty folders are not represented by current metadata and therefore are not shown unless they contain at least one loaded file.
- Duplicate filenames in different folders remain distinguishable by path context, especially in all-files list mode.
- Search and filters must not produce stale folder entries that contain no visible matching files.
- Phase 1 infinite scroll uses the existing offset/limit backend contract, so folder counts must be labeled as loaded/visible counts or omitted rather than presented as global totals.
- Phase 1 folder mode may discover additional folders as more pages load; Phase 2 backend folder browsing is the planned fix if that behavior is not good enough.
- If Reliquary preview/thumbnail presign data is unavailable while Engram metadata is loaded, folder/list controls still render and file preview behavior degrades the same way the current grid does.

## Requirements

### Functional Requirements

- **FR-001**: The gallery MUST provide a folder grouping mode derived entirely from existing `EngramFile.filePath` metadata.
- **FR-002**: The gallery MUST provide an all-files mode that shows files without folder grouping while preserving directory context for each file.
- **FR-003**: The gallery MUST provide grid and list layout modes for the same filtered file set.
- **FR-004**: Folder mode MUST support navigating into child folders and back to parent/root folders without reloading the app.
- **FR-005**: Existing search, file-type filters, tag filters, refresh, upload navigation, and file detail navigation MUST continue to work in every view/grouping mode.
- **FR-006**: View mode, grouping mode, and current folder path SHOULD be reflected in `/vault` route query parameters so refreshes and browser navigation preserve the visible gallery state.
- **FR-007**: The implementation MUST be frontend-only unless a documented pagination completeness issue requires a future backend contract; this feature MUST NOT change Engram, Reliquary, Synapse, queue, storage, or auth contracts.
- **FR-008**: The folder behavior SHOULD reuse the Reliquary frontend's proven approach for deriving visible folders/files from display paths, adapted to Mind Palace models and styling.
- **FR-009**: `cd app && flutter analyze` MUST report zero errors after implementation.
- **FR-010**: Phase 1 MUST preserve scroll-down-to-load pagination behavior and MUST NOT introduce manual next/previous page buttons.
- **FR-011**: Phase 1 MUST continue using the current Engram `offset`/`limit` file-list API and frontend `hasMore` behavior unless implementation finds a blocking defect.
- **FR-012**: Phase 2 SHOULD introduce a backend pagination contract with explicit `items`, `next_cursor`, and `has_more` fields so the frontend no longer infers whether more files exist from page size.
- **FR-013**: Phase 2 SHOULD evaluate a folder-aware browse endpoint that returns immediate child folders and direct files for a normalized path.

### Key Entities

- **Gallery View Mode**: User-facing layout state with values `grid` and `list`.
- **Gallery Grouping Mode**: User-facing organization state with values `folders` and `allFiles`.
- **Gallery Folder Path**: Current normalized directory path shown in folder mode, empty at root.
- **Folder Entry**: Frontend-derived item containing a folder display name, normalized path, and visible descendant count.
- **Visible Gallery Item**: Either a folder entry or an `EngramFile` projected into the current view/grouping mode.
- **Paged File Result**: Phase 2 backend response shape containing file items plus explicit pagination metadata.
- **Folder Browse Result**: Phase 2 backend response shape containing child folders, direct files, and explicit pagination metadata for one folder path.

### Contracts & Integration Impact

- **Affected Components**: Phase 1 affects `app/` Flutter client only. `reliquary/frontend/` is read as a reference only. Phase 2 may affect `engram/backend/` API.
- **Contracts**: Phase 1 has no API, event schema, queue, storage key, authentication, or fixture changes. Phase 2 should add or version an Engram file-list/browse API contract.
- **State & Migrations**: No database/object storage migrations. Optional route query state only.
- **Idempotency/Retry Behavior**: No event-producing changes. Existing file list refresh/retry behavior remains owned by `FileListProvider`.
- **Secrets/Configuration**: No new secrets, credentials, environment variables, or `.data/` state.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A user can browse from gallery root into a nested folder and back to root using only the gallery UI.
- **SC-002**: A user can switch between grid and list layouts without losing active search, tag filters, file-type filters, or current folder context.
- **SC-003**: A user can switch between folder grouping and all-files mode and still open the same files in the existing detail screen.
- **SC-004**: Duplicate filenames in different folders are distinguishable in all-files mode by visible path/location context.
- **SC-005**: Additional files load automatically when the user scrolls near the bottom; no next-page button is required.
- **SC-006**: Flutter analysis and focused gallery tests pass for the changed frontend behavior.

## Assumptions

- Existing Engram file metadata includes enough `file_path` information to derive meaningful user-facing folders for Reliquary-originated uploads.
- The feature targets the primary Flutter client in `app/`; Reliquary's Flutter frontend is a reference implementation, not a submodule to modify.
- Empty directories do not need to be displayed because current metadata describes files, not standalone directory records.
- Persisting view state in route query parameters is sufficient; no durable user preference store is required for the first implementation.
- Phase 1 accepts the current backend's offset/limit pagination limitations and avoids presenting incomplete folder counts as authoritative totals.
