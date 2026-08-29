# Tasks: Engram Folder Listing

**Input**: Design documents from `/specs/009-engram-folder-listing/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/folder-listing-contract.md](./contracts/folder-listing-contract.md), [quickstart.md](./quickstart.md)

**Tests**: Required. Engram's SQL has no coverage today because `fakeDB` discards queries, so pure helpers are extracted specifically to be testable and their tests come first.

**Organization**: Grouped by user story. Engram owns the API and migration; the root app consumes them. User Story 3 is independent of the backend and can ship first.

**Parallel marker**: `[P]` means no file overlap with other `[P]` tasks in the same block.

## Phase 1: Setup

**Purpose**: Confirm sources and current data shape before editing.

- [ ] T001 Verify Engram API sources in `engram/backend/internal/api/files.go`, `engram/backend/internal/api/router.go`, `engram/backend/internal/api/files_test.go`, and `engram/backend/internal/model/file.go`
- [ ] T002 Verify client sources in `app/lib/engram_service.dart`, `app/lib/providers/file_list_provider.dart`, `app/lib/widgets/gallery/gallery_view_model.dart`, and `app/lib/screens/gallery_screen.dart`
- [X] T003 Run the legacy-row diagnostic from [quickstart.md](./quickstart.md) step 0 — **done 2026-08-28**: 20 rows, all `ready`, `legacy_layout=0`, `backfill_targets=0`, `filename_is_key=0`, `has_display_path=0`. Collation is `C`. No backfill needed; carry these counts into the PR description

**Checkpoint**: The shape of existing data is known before any migration is written.

---

## Phase 2: Foundational

**Purpose**: Testable primitives that both API stories depend on.

**CRITICAL**: Complete before User Story 1.

- [X] T004 [P] Add failing tests for `normalizeDisplayPath` covering leading/trailing slashes, `\` separators, `.` and `..` segments, duplicate separators, and the empty string in `engram/backend/internal/api/files_test.go`
- [X] T005 [P] Add failing tests for `escapeLikePattern` covering `_`, `%`, and `\` in `engram/backend/internal/api/files_test.go`
- [X] T006 Add failing tests for `buildFileFilters` asserting condition text and positional argument ordering for owner, status, device, `q`, `type`, `from`, `to`, and repeated `tag` in `engram/backend/internal/api/files_test.go`
- [X] T007 Implement `normalizeDisplayPath` and `escapeLikePattern` in `engram/backend/internal/api/files.go`, mirroring `GalleryFolderPath._normalizePath`
- [X] T008 Extract the filter construction currently inlined in `handleListFiles` (`engram/backend/internal/api/files.go:84-158`) into a pure `buildFileFilters` returning joins, conditions, and args, and rewrite `handleListFiles` to use it with no behavior change
- [X] T009 Run `cd engram/backend && gofmt -l . && go test ./internal/api`

**Checkpoint**: Shared helpers are covered and `GET /api/files` behaves exactly as before.

---

## Phase 3: User Story 3 - Storage Keys Never Become Folders (Priority: P1)

**Goal**: The client display-path fallback can never return a storage key as a display path.

**Independent Test**: Project a file with a basename `filename` and a `file_path` in the pre-restructure layout; assert the display path is the basename.

**Note**: Independent of all backend work. Ship first — it fixes a live, user-visible defect.

### Tests for User Story 3

- [X] T010 [P] [US3] Add failing test asserting `file_path=akadmin/2026/06/report.pdf` with `filename=report.pdf` projects to `report.pdf` and yields no folder, in `app/test/gallery/gallery_view_model_test.dart`
- [X] T011 [P] [US3] Add tests pinning the still-correct cases: `files/<u>/<yyyy>/<mm>/docs/x.pdf` projects to `docs/x.pdf`, and a `filename` already containing `/` is used unchanged without consulting `file_path`, in `app/test/gallery/gallery_view_model_test.dart`

### Implementation for User Story 3

- [X] T012 [US3] Replace the final `parts.join('/')` fallback in `displayPathForFile` with a basename return in `app/lib/widgets/gallery/gallery_view_model.dart`
- [X] T013 [US3] Run `cd app && dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test test/gallery`

**Checkpoint**: No storage key can render as a folder tree, whatever the database contains.

---

## Phase 4: User Story 4 - Legacy Data Is Verified, Not Assumed (Priority: P3)

**Goal**: Add the prefix index. No row data is touched — T003 established there is nothing to repair.

**Independent Test**: Apply the migration; verify the index exists and the row count and every `filename` are unchanged.

- [X] T014 [US4] Create `engram/backend/internal/db/migrations/005_folder_listing_index.up.sql` with the `idx_files_owner_filename` index and the collation comment, exactly as specified in [data-model.md](./data-model.md)
- [X] T015 [US4] Create `engram/backend/internal/db/migrations/005_folder_listing_index.down.sql` dropping that index
- [X] T016 [US4] Apply migrations against the local Engram database and confirm with `\d files` that `idx_files_owner_filename` exists, per [quickstart.md](./quickstart.md) step 1
- [X] T017 [US4] Confirm the migration modified no data: row count still 20 and the diagnostic counts unchanged — verified by content digest `e32ed2f7d885059a8f99f8a5ee937e89` before and after, and `schema_migrations` moving 4 → 5 clean

**Checkpoint**: Prefix queries are indexed and the table's data is untouched.

---

## Phase 5: User Story 1 - Complete Folder Tree At Every Level (Priority: P1) MVP

**Goal**: Engram serves directory listings; the gallery renders them instead of deriving them.

**Independent Test**: With files spanning more than one page across several folders, open folder view at the root and verify every folder appears with a correct recursive count before any further page is fetched.

### Tests for User Story 1

- [X] T019 [P] [US1] Add failing handler test asserting `scope=folder&path=docs` restricts to direct children and rejects an unknown `scope` with `400`, in `engram/backend/internal/api/files_test.go`
- [X] T020 [P] [US1] Add failing handler test for `GET /api/folders` response shape `{name, path, file_count}`, case-insensitive ordering, and `[]` for an empty directory, in `engram/backend/internal/api/files_test.go`
- [X] T021 [P] [US1] Add failing test asserting the folder query and the file query share the same filter conditions when `type` and `tag` are active, in `engram/backend/internal/api/files_test.go`
- [X] T022 [P] [US1] Add failing Dart test for `FolderEntry.fromJson` in `app/test/gallery/gallery_view_model_test.dart`

### Implementation for User Story 1

- [X] T023 [US1] Add `model.Folder` with `name`, `path`, and `file_count` JSON tags in `engram/backend/internal/model/file.go`
- [X] T024 [US1] Add `path` and `scope` handling to `handleListFiles`, applying the direct-child predicate when `scope=folder`, in `engram/backend/internal/api/files.go`
- [X] T025 [US1] Implement `handleListFolders` using `buildFileFilters` plus the `split_part`/`position` aggregate from [contracts/folder-listing-contract.md](./contracts/folder-listing-contract.md), in `engram/backend/internal/api/files.go`
- [X] T026 [US1] Register `GET /api/folders` on the `protected` mux in `engram/backend/internal/api/router.go`
- [X] T027 [US1] Run `cd engram/backend && gofmt -l . && go test ./...`
- [X] T028 [US1] Add `path` and `scope` parameters to `listFiles` and a new `listFolders` returning `List<FolderEntry>` in `app/lib/engram_service.dart`
- [X] T029 [US1] Add `FolderEntry.fromJson` and delete `visibleFoldersFor` from `app/lib/widgets/gallery/gallery_view_model.dart`
- [X] T030 [US1] Simplify `visibleFilesFor` to project and label only, since the server now returns direct children, in `app/lib/widgets/gallery/gallery_view_model.dart`
- [X] T031 [US1] Add `folders` and `folderPath` to `FileListState` and a `setFolder(path, mode)` that resets offset and reloads files and folders together, in `app/lib/providers/file_list_provider.dart`
- [X] T032 [US1] Call `setFolder` from `_openFolder`, `_goUpFolder`, and the route-state sync, and read folders from the provider instead of computing them, in `app/lib/screens/gallery_screen.dart`
- [X] T033 [US1] Update `app/test/gallery/gallery_view_model_test.dart` and `app/test/gallery/gallery_view_modes_test.dart` for the removed `visibleFoldersFor` and the simplified `visibleFilesFor`
- [X] T034 [US1] Run `cd app && dart format --output=none --set-exit-if-changed lib test && flutter analyze && flutter test test/gallery`

**Checkpoint**: Folder view is complete and correct at every level, independent of pagination.

---

## Phase 6: User Story 2 - Search Still Flattens The Tree (Priority: P2)

**Goal**: An active search returns matches from every folder and shows no folder rows.

**Independent Test**: Search from inside a folder and confirm results from outside it appear.

- [X] T035 [US2] Force `scope=all` in `loadFiles` whenever `searchQuery` is non-empty, in `app/lib/providers/file_list_provider.dart`
- [X] T036 [US2] Suppress folder rows and show full display paths while a search is active in `app/lib/screens/gallery_screen.dart`
- [X] T037 [US2] Add a test asserting a non-empty search query produces an unscoped request in `app/test/gallery/gallery_view_modes_test.dart`
- [X] T038 [US2] Run `cd app && flutter analyze && flutter test test/gallery`

**Checkpoint**: Search behaves exactly as it did before folder scoping existed.

---

## Phase 7: Polish

- [X] T039 [P] Document `GET /api/folders` and the `path`/`scope` parameters in `engram/CLAUDE.md` (API Endpoints section), `engram/README.md` (endpoint table), and `engram/docs/architecture.md` (Endpoints list)
- [X] T040 [P] Add a changelog entry to `engram/CHANGELOG.md` covering the new endpoint, migration 005, and the widened search surface from the `tsv` regeneration
- [ ] T041 **UNBLOCKED** Perform the manual UI pass in [quickstart.md](./quickstart.md) step 4, including the underscore-named folder case, and attach screenshots to the PR — was blocked because `app/lib/screens/upload_screen.dart` never passed `relativePath` to `ReliquaryService.uploadFile` and Reliquary's `sanitizeFilename` is `path.Base`, so every folder upload flattened. Fixed by the `PickedFile` wrapper (separate change, `app/` only). Re-upload a nested folder before running this pass; the 25 existing rows are all flat
- [ ] T042 Commit inside `engram/` first, then update the root submodule pointer together with the `app/` changes, per constitution principle II

---

## Dependencies

- Phase 1 blocks everything.
- Phase 2 blocks Phase 5. T008 must land before T024 and T025.
- Phase 3 (US3) is independent and may ship on its own.
- Phase 4 (US4) is a one-line index migration and is independent; land it any time before Phase 5 is measured for performance.
- Phase 6 depends on Phase 5.
- T027 gates the client tasks T028-T034.

## Implementation Strategy

Ship User Story 3 first as a standalone fix — it is three lines plus tests and removes a visible
defect regardless of the backend. Then Phase 2 and Phase 4 in either order, then Phase 5 as the MVP,
then Phase 6. Each checkpoint leaves the vault in a working state.

Note that the local dataset has no folder uploads and no non-`ready` files, so the automated tests
carry the correctness burden; the manual pass in T041 requires uploading nested content first.
