# Feature Specification: Frontend Performance Optimization

**Feature Branch**: `005-frontend-performance`

**Created**: 2026-06-24

**Status**: Draft

**Input**: User description: "Fix Flutter frontend laggy mount/unmount and scroll performance issues identified in audit"

## User Scenarios & Testing

### User Story 1 - Smooth Gallery Scrolling (Priority: P1)

As a user, when I open the gallery with many artifacts, I want scrolling to feel smooth and responsive so that I can browse without frame drops or stuttering.

**Why this priority**: The gallery is the primary entry point after login. Current layout builds every tile up front, causing jank on mount and scroll.

**Independent Test**: Open the gallery with 100+ files and scroll rapidly. The UI should remain responsive and only visible tiles should be built.

**Acceptance Scenarios**:

1. **Given** the gallery contains many files, **When** the user scrolls, **Then** only visible tiles are built and frame drops are eliminated.
2. **Given** the gallery grid is displayed, **When** filters or pagination change, **Then** existing tile state is preserved where possible via stable keys.

---

### User Story 2 - Stable File Previews (Priority: P2)

As a user, when I open a file detail screen, I want the preview (image or PDF) to load once and stay loaded so that it does not flicker or re-download when the parent rebuilds.

**Why this priority**: Re-fetching presigned URLs and PDF bytes on every rebuild causes visible flicker and wasted network requests.

**Independent Test**: Open a file detail screen and trigger a parent rebuild (e.g., theme change or progress update). The preview should not reload.

**Acceptance Scenarios**:

1. **Given** an image preview is displayed, **When** the parent widget rebuilds, **Then** the image is not re-requested.
2. **Given** a PDF preview is displayed, **When** the parent widget rebuilds, **Then** PDF bytes are not downloaded again.

---

### User Story 3 - Responsive Upload Screen (Priority: P2)

As a user, when I drag files over the upload drop zone or upload progress updates, I want the rest of the screen to remain responsive so that hover states and progress feel immediate.

**Why this priority**: Current drag-hover state and upload progress call `setState` on the whole screen, rebuilding the entire queue on every minor update.

**Independent Test**: Drag files over the drop zone and upload multiple files. The drop zone animation and progress updates should be smooth without rebuilding the file list header.

**Acceptance Scenarios**:

1. **Given** the user drags files over the drop zone, **When** hover state changes, **Then** only the drop zone rebuilds.
2. **Given** an upload is in progress, **When** one file's progress updates, **Then** other tiles and the header are not rebuilt.

---

### User Story 4 - Efficient Admin & Settings Screens (Priority: P3)

As a user, when I type in the admin search field or toggle settings options, I want the screen to respond instantly without recomputing large lists on every keystroke.

**Why this priority**: Search filtering and filter draft state currently recompute inside `build`, causing unnecessary work.

**Independent Test**: Type in the admin search field and open the gallery filter overlay. Typing should be smooth and filtering should not block the UI.

**Acceptance Scenarios**:

1. **Given** the admin user list is displayed, **When** the user types a search query, **Then** the filtered list is memoized and updates without blocking.
2. **Given** the gallery filter overlay is open, **When** draft selections change, **Then** the gallery behind it does not rebuild until the user applies filters.

### Edge Cases

- What happens when the gallery has zero files after filtering? Grid should show an empty state without crashing.
- What happens if a presigned thumbnail URL expires while scrolling? Cache should respect TTL or be invalidated explicitly.
- What happens when a file upload fails and retry is triggered? Upload state updates should still be localized to the affected tile.
- Which component owns recovery if Engram/Reliquary is unavailable? Existing error handling is preserved; performance changes do not alter retry logic.

## Requirements

### Functional Requirements

- **FR-001**: The gallery MUST use viewport-recycled list/grid layout (`CustomScrollView` + `SliverGrid`) so only visible tiles are built.
- **FR-002**: List items (gallery tiles, upload tiles, admin user tiles, tag chips, theme cards) MUST have stable `Key`s to allow Flutter to reuse elements efficiently.
- **FR-003**: `ImagePreview` and `PdfPreview` MUST cache their network futures so they are not re-requested on parent rebuilds.
- **FR-004**: `Image.network` calls MUST provide `cacheWidth`/`cacheHeight` capped to the rendered pixel size to reduce decode work.
- **FR-005**: `UploadScreen` drag-hover state MUST be localized so the entire screen does not rebuild on drag enter/exit events.
- **FR-006**: `GalleryScreen` MUST use Riverpod `select` to watch only the slice of state needed by each section.
- **FR-007**: `AdminScreen` search/filter results MUST be memoized and not recomputed on every build.
- **FR-008**: The gallery filter overlay MUST keep draft state inside the overlay widget and only rebuild the gallery when filters are applied.
- **FR-009**: All changes MUST preserve existing visual layout and behavior — no user-visible changes beyond performance improvements.
- **FR-010**: `flutter analyze` MUST report zero errors after each change.

### Key Entities

- **GalleryFile**: Existing `EngramFile` model; displayed via `FileTile` with stable `ValueKey(file.id)`.
- **UploadTask**: Existing upload queue item; displayed via `UploadFileTile` with stable `ValueKey(task.id)`.
- **PreviewCache**: Conceptual cache layer for presigned image URLs and PDF bytes keyed by file identifier.
- **AdminUser**: Existing user map; displayed via `_UserTile` keyed by username.

### Contracts & Integration Impact

- **Affected Components**: `app/` only.
- **Contracts**: No API, event, queue, storage, or authentication contract changes.
- **State & Migrations**: No migrations. Runtime state remains in providers and widget state.
- **Idempotency/Retry Behavior**: No event-producing changes; existing retry behavior is preserved.
- **Secrets/Configuration**: No new secrets or environment variables.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Gallery scrolling remains smooth with 100+ files (no visible frame drops during rapid scroll on Linux desktop).
- **SC-002**: `flutter analyze` reports zero errors.
- **SC-003**: `flutter test` passes all existing and newly added tests.
- **SC-004**: File detail previews do not refetch when unrelated parent state changes (verified by widget test asserting one network request).
- **SC-005**: Upload drag hover and progress updates only rebuild the affected sub-tree (verified by widget test or `debugPrintRebuildDirtyWidgets`).

## Assumptions

- Riverpod (`flutter_riverpod`) is available and already used for state management.
- No backend changes are required; performance improvements are purely client-side.
- Target platforms remain Linux desktop (primary) and Flutter web (secondary).
- Existing widget tests can be extended to verify rebuild boundaries and caching behavior.
- The current `FileTile` presigned URL fetch can be moved to a provider or memoized future without breaking conditional import patterns.
