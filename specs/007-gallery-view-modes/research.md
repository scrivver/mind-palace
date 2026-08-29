# Research: Gallery View Modes

## Decision: Derive folders from `EngramFile.filePath` in the Flutter client

**Rationale**: The feature is explicitly frontend-only, and `EngramFile` already exposes `filePath`, `filename`, `size`, `mimeType`, `mtime`, and tags. Reliquary's frontend already derives folders by projecting file paths into visible folder entries and direct child files; the same pattern fits Mind Palace without API changes.

**Alternatives considered**:

- Add an Engram folder API: rejected for this stage because it would change backend/API scope and violate the requested frontend-only constraint.
- Use Reliquary's object list directly: rejected because the Mind Palace gallery is based on Engram metadata and existing filters/search already flow through `FileListProvider`.

## Decision: Normalize storage paths before display

**Rationale**: Reliquary-originated paths can include storage/user prefixes such as `files/alice/2026/06/report.pdf`. Users should see meaningful directories like `2026/06/report.pdf`, while malformed or unexpected paths should still produce a safe fallback based on available path/filename data.

**Alternatives considered**:

- Show raw `filePath`: rejected because it exposes implementation prefixes and makes folder browsing noisy.
- Strip a hardcoded username: rejected because the current auth username may not always match historical file paths or non-Reliquary metadata.

## Decision: Add two independent mode axes: view mode and grouping mode

**Rationale**: Grid/list layout and folder/all-files organization solve different user needs. Keeping them independent allows `folder + grid`, `folder + list`, `all files + grid`, and `all files + list` without hidden coupling.

**Alternatives considered**:

- Single combined enum for all four states: rejected because route parsing and UI controls become less clear.
- Separate screens/routes for list and folder browsing: rejected because the existing `/vault` gallery already owns search, filters, upload navigation, and detail navigation.

## Decision: Preserve view state through `/vault` query parameters

**Rationale**: Existing gallery search/type/tag state is already encoded in `/vault` query parameters by `app_router.dart`. Adding `view`, `group`, and `path` preserves refresh/deep-link behavior and matches the existing routing pattern.

**Alternatives considered**:

- Store view preferences only in widget state: rejected because refresh/back navigation would lose state.
- Add persistent preferences: rejected for first implementation because no durable preference requirement exists and route state is sufficient.

## Decision: Keep search global across folders

**Rationale**: Reliquary hides folder rows during search and shows matching files across all directories. This avoids forcing users to know which folder contains a match. It also preserves current gallery search semantics, where search applies to the current loaded file set rather than a folder subtree.

**Alternatives considered**:

- Search only inside the current folder: rejected because it makes existing gallery search less useful and can hide expected results.
- Show folders containing matches: deferred because it adds more state and test cases without being required for the first improvement.

## Decision: Implement in two phases, starting with frontend infinite scroll over the current API

**Rationale**: The current Engram backend exposes `offset`/`limit` pagination and the Flutter gallery already loads more files as the user scrolls. The immediate UX improvement should keep that behavior, avoid page buttons, and stay frontend-only. Folder trees and all-files counts are only as complete as the loaded metadata, so Phase 1 must avoid authoritative totals unless all relevant pages are loaded.

**Alternatives considered**:

- Add backend folder counts immediately: rejected for Phase 1 because it expands scope beyond the requested UX pass.
- Replace infinite scroll with next/previous buttons: rejected because the preferred behavior is scroll-down-to-load.
- Ignore pagination in folder mode: rejected because folder entries and counts can mislead users when only the first page is loaded.

## Decision: Use cursor pagination as the Phase 2 backend target

**Rationale**: The current backend returns a bare JSON array and the frontend infers `hasMore` from `files.length == pageSize`. A future backend response with `items`, `next_cursor`, and `has_more` would remove that guess and make infinite scroll more reliable. Cursor pagination is also more stable than offset pagination when files are inserted or deleted while a user scrolls.

**Alternatives considered**:

- Keep offset pagination permanently: acceptable for Phase 1, but weaker for long-lived infinite scroll because changing data can skip or duplicate rows.
- Add `total` to offset pagination only: useful for counts, but it does not fix offset drift and can be expensive with filters/search.
- Use page numbers: rejected because page numbers are less natural for infinite scroll and do not improve stability.

## Decision: Evaluate a folder-aware browse endpoint in Phase 2

**Rationale**: A purely frontend folder tree can only derive folders from loaded file pages. A backend browse endpoint can return immediate child folders and direct files for a path, which is the cleanest way to make folder mode complete without fetching every file first.

**Alternatives considered**:

- Continue deriving folder mode forever from loaded pages: acceptable for small datasets, but can cause folders to appear late as more pages load.
- Fetch every matching file before showing folder mode: rejected as a default because large galleries would delay first render and increase backend load.

## Decision: Use focused gallery helper/widget tests plus Flutter analysis

**Rationale**: Most risk is deterministic projection/routing logic and visible widget layout. Focused tests can cover path normalization, folder derivation, mode filtering, and route state without needing full infrastructure.

**Alternatives considered**:

- End-to-end infrastructure-only verification: rejected as excessive for frontend-only projection logic.
- Manual testing only: rejected because path derivation and route query behavior are easy to regress.
