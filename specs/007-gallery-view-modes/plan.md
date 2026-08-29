# Implementation Plan: Gallery View Modes

**Branch**: `007-gallery-view-modes` | **Date**: 2026-07-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/007-gallery-view-modes/spec.md`

## Summary

Improve the Flutter gallery in `app/` with folder browsing, a list layout, a toggle between directory grouping and all-files browsing, and scroll-down-to-load behavior. The work is split into two phases: Phase 1 is frontend-only over the current Engram offset/limit API; Phase 2 is a planned backend API improvement for cursor pagination and folder-aware browsing if folder completeness requires it.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x

**Primary Dependencies**: `flutter_riverpod`, `go_router`, existing Material icons/widgets. No new dependencies.

**Storage**: Phase 1 uses existing Engram metadata API results in memory; no new durable storage. Optional `/vault` route query parameters for view state. Phase 2 may add API response metadata, but no storage migration is expected.

**Testing**: `cd app && flutter analyze`; focused Flutter tests under `app/test/gallery/`; manual smoke test via `start-app` or `cd app && flutter run`.

**Target Platform**: Flutter web and desktop client. Web route-state preservation is primary; desktop/native should keep equivalent in-memory behavior.

**Project Type**: Flutter client application in a Nix-managed monorepo.

**Performance Goals**: View toggles and folder navigation should be immediate for already loaded file metadata. Infinite scroll should fetch the next page before the user hits the hard bottom. Avoid thumbnail requests for folder entries and list rows unless an existing thumbnail widget explicitly needs them.

**Constraints**: Phase 1 is frontend-only; no Engram, Reliquary, Synapse, storage, queue, auth, schema, or environment-variable changes. UI must remain responsive at narrow and desktop widths. Phase 2 backend work must be planned separately before implementation.

**Scale/Scope**: One gallery screen, existing file list provider, existing file tile/detail behavior, new frontend-only projection helpers/widgets, and focused tests.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: Development and verification use the root Nix environment (`nix develop`) and existing app commands: `cd app && flutter analyze`, `cd app && flutter test`, and manual smoke via `start-app` where needed.
- **Component boundaries**: Phase 1 changes are scoped to `app/` plus Spec Kit docs. `app/README.md` was read. `reliquary/README.md` and `reliquary/CLAUDE.md` were read because Reliquary's frontend folder behavior is used as reference only. Phase 2 may involve `engram/backend/` and will require Engram guidance review again at implementation time.
- **Contract-driven integration**: Phase 1 has no API, file-event, queue, storage key, authentication, schema, fixture, or service-to-service contract changes. No event-producing behavior. Existing Engram `listFiles` and Reliquary thumbnail/detail calls are reused. Phase 2 must define an Engram API contract for cursor pagination and optional folder browse before implementation.
- **Verification proportional to change**: Add focused tests for path normalization, folder projection, route query parsing/building, and list/grid/folder rendering where practical. Run `cd app && flutter analyze` and targeted/gallery Flutter tests. Capture screenshots or manual notes for visible gallery workflows during implementation.
- **State and secret hygiene**: No runtime state outside existing Flutter memory and route query parameters. No `.data/` writes, migrations, generated secrets, credentials, or environment variables.

Initial gate result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/007-gallery-view-modes/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── gallery-ui-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
app/
  lib/
    models/
      engram_file.dart              # Existing file metadata source
    providers/
      file_list_provider.dart       # Existing loading/filter provider; possible route/view state integration
    router/
      app_router.dart               # /vault query parameter parsing/building
    screens/
      gallery_screen.dart           # Main view controls and sliver composition
    widgets/
      gallery/
        file_tile.dart              # Existing grid file card
        ...                         # New folder/list/infinite-scroll controls and rows as needed
  test/
    gallery/
      ...                           # Focused gallery projection and widget tests

reliquary/
  frontend/lib/screens/gallery_screen.dart  # Reference only; no planned edits

engram/
  backend/internal/api/files.go     # Phase 2 candidate only; no Phase 1 edits
```

**Structure Decision**: Implement Phase 1 inside the primary Flutter client (`app/`) using small gallery-specific helpers/widgets. Keep backend metadata and storage contracts unchanged in Phase 1. Use Reliquary frontend logic as a reference for deriving visible folders/files, not as a shared dependency. Treat Phase 2 backend pagination/folder browsing as follow-up work that requires a separate contract review.

## Phase Strategy

### Phase 1: Frontend UX over current API

- Keep Engram's current `GET /api/files?offset=...&limit=...` API.
- Preserve scroll-down-to-load behavior; do not add next/previous page buttons.
- Reset pagination when search, tags, type, sort, grouping, or folder path changes.
- Derive folders from loaded `EngramFile.filePath` values.
- Avoid authoritative folder totals unless all relevant pages have been loaded; prefer no count or "loaded" count copy.
- Deliver grid/list and folders/all-files modes with route-state preservation.

### Phase 2: Backend pagination and folder browse

- Replace frontend `files.length == pageSize` inference with explicit backend pagination metadata.
- Prefer cursor pagination for stable infinite scroll: `items`, `next_cursor`, `has_more`.
- Keep cursor values opaque to clients and include sort key plus stable tiebreaker server-side.
- Evaluate a folder-aware browse endpoint returning immediate child folders and direct files for a normalized path.
- Keep old offset/limit behavior or add a versioned/new endpoint during migration.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/gallery-ui-contract.md](./contracts/gallery-ui-contract.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Nix-first reproducibility**: Still satisfied by existing `nix develop`, `flutter analyze`, `flutter test`, and `start-app` flows.
- **Component boundaries**: Phase 1 design remains limited to `app/`; Reliquary stays reference-only. Phase 2 backend work is documented but not included in this implementation pass.
- **Contract-driven integration**: UI contract documents route/query behavior and Phase 2 API direction. No backend or event contracts change in Phase 1.
- **Verification proportional to change**: Data-model and UI contract identify focused unit/widget tests plus manual gallery smoke coverage.
- **State and secret hygiene**: No durable state, `.data/`, secret, migration, or environment-variable impact.

Post-design gate result: PASS.

## Complexity Tracking

No constitution violations.
