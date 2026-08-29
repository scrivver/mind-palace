# Tasks: Gallery View Modes

**Input**: Design documents from `/specs/007-gallery-view-modes/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/gallery-ui-contract.md](./contracts/gallery-ui-contract.md), [quickstart.md](./quickstart.md)

**Tests**: Focused Flutter tests are required by SC-006 and the plan. Write tests before implementation where practical, then run targeted gallery tests and Flutter analysis.

**Organization**: Tasks are grouped by user story so each story can be implemented and verified independently. Phase 1 implementation is frontend-only in `app/`; Phase 2 backend API work is documented as follow-up, not implemented here.

## Phase 1: Setup

**Purpose**: Confirm existing app structure and prepare gallery-specific files.

- [X] T001 Verify existing gallery source and test paths in `app/lib/screens/gallery_screen.dart`, `app/lib/widgets/gallery/file_tile.dart`, `app/lib/providers/file_list_provider.dart`, `app/lib/router/app_router.dart`, and `app/test/gallery/file_tile_test.dart`
- [X] T002 Create gallery helper test file `app/test/gallery/gallery_view_model_test.dart`
- [X] T003 Create gallery widget test file `app/test/gallery/gallery_view_modes_test.dart`

---

## Phase 2: Foundational

**Purpose**: Shared frontend types and helpers required by every story.

**CRITICAL**: Complete this phase before user story implementation.

- [X] T004 [P] Add failing path normalization and folder projection tests in `app/test/gallery/gallery_view_model_test.dart`
- [X] T005 [P] Add failing route-state parsing/building tests for gallery view/group/path query parameters in `app/test/gallery/gallery_view_model_test.dart`
- [X] T006 Implement `GalleryViewMode`, `GalleryGroupingMode`, `GalleryFolderPath`, `FolderEntry`, and `GalleryFileProjection` helpers in `app/lib/widgets/gallery/gallery_view_model.dart`
- [X] T007 Implement gallery route-state parse/build helpers for `q`, `type`, `tags`, `view`, `group`, and `path` in `app/lib/widgets/gallery/gallery_view_model.dart`
- [X] T008 Export or import the new gallery helper from `app/lib/screens/gallery_screen.dart` without changing current gallery behavior
- [X] T009 Run focused helper tests with `cd app && flutter test test/gallery/gallery_view_model_test.dart`

**Checkpoint**: Gallery view state and projection helpers are tested and ready for UI stories.

---

## Phase 3: User Story 1 - Browse Files By Folder (Priority: P1) MVP

**Goal**: Users can switch to folder grouping, see folders derived from file paths, navigate into child folders, and go back to parent/root folders.

**Independent Test**: Seed files with paths like `files/alice/2026/06/report.pdf` and `files/alice/photos/image.jpg`, enable folder grouping, open `2026`, open `06`, and verify only direct children for each folder level appear.

### Tests for User Story 1

- [X] T010 [P] [US1] Add failing helper tests for root folders, nested folders, direct child files, malformed paths, and empty root path behavior in `app/test/gallery/gallery_view_model_test.dart`
- [X] T011 [P] [US1] Add failing widget tests for folder cards/rows, opening a folder, and using the up/back folder control in `app/test/gallery/gallery_view_modes_test.dart`

### Implementation for User Story 1

- [X] T012 [P] [US1] Create folder card widget for grid mode in `app/lib/widgets/gallery/folder_tile.dart`
- [X] T013 [P] [US1] Create folder row widget for list-compatible folder rendering in `app/lib/widgets/gallery/folder_row.dart`
- [X] T014 [US1] Add local gallery grouping state, current folder path state, and folder navigation callbacks in `app/lib/screens/gallery_screen.dart`
- [X] T015 [US1] Render folder entries before direct child files when folder grouping is active in `app/lib/screens/gallery_screen.dart`
- [X] T016 [US1] Add folder breadcrumb/up control and root/current folder label behavior in `app/lib/screens/gallery_screen.dart`
- [X] T017 [US1] Ensure search hides folder entries and shows matching files globally in `app/lib/screens/gallery_screen.dart`
- [X] T018 [US1] Run User Story 1 tests with `cd app && flutter test test/gallery/gallery_view_model_test.dart test/gallery/gallery_view_modes_test.dart`

**Checkpoint**: Folder browsing MVP is functional and independently testable.

---

## Phase 4: User Story 2 - Switch Between Grid And List Views (Priority: P2)

**Goal**: Users can switch between the existing grid and a dense list view without losing folder, search, filter, or loaded-file state.

**Independent Test**: Toggle from grid to list and back with filters active and verify the same logical files/folders remain visible in a different layout.

### Tests for User Story 2

- [X] T019 [P] [US2] Add failing widget tests for grid/list toggle preserving folder path and filters in `app/test/gallery/gallery_view_modes_test.dart`
- [X] T020 [P] [US2] Add failing widget tests for file rows showing name, path/type context, size, and modified date in `app/test/gallery/gallery_view_modes_test.dart`

### Implementation for User Story 2

- [X] T021 [P] [US2] Create compact file row widget in `app/lib/widgets/gallery/file_row.dart`
- [X] T022 [US2] Add grid/list segmented icon controls to the gallery toolbar in `app/lib/screens/gallery_screen.dart`
- [X] T023 [US2] Render `SliverList` rows for folders and files when list mode is active in `app/lib/screens/gallery_screen.dart`
- [X] T024 [US2] Preserve current search, filters, grouping mode, current folder path, and loaded files when toggling view mode in `app/lib/screens/gallery_screen.dart`
- [X] T025 [US2] Run User Story 2 tests with `cd app && flutter test test/gallery/gallery_view_modes_test.dart`

**Checkpoint**: Grid/list switching works without breaking folder browsing.

---

## Phase 5: User Story 3 - View All Files With Or Without Directories (Priority: P3)

**Goal**: Users can toggle between folder grouping and all-files mode, with all-files mode showing directory context and preserving existing flat-gallery behavior.

**Independent Test**: Toggle from folder mode to all-files mode with files in multiple directories, verify all matching files appear together, then toggle back to folder mode without refresh.

### Tests for User Story 3

- [X] T026 [P] [US3] Add failing helper tests for all-files projections, duplicate filenames in different directories, and directory context labels in `app/test/gallery/gallery_view_model_test.dart`
- [X] T027 [P] [US3] Add failing widget tests for grouping toggle, all-files rendering, and returning to folder mode in `app/test/gallery/gallery_view_modes_test.dart`

### Implementation for User Story 3

- [X] T028 [US3] Add folder/all-files segmented icon controls to the gallery toolbar in `app/lib/screens/gallery_screen.dart`
- [X] T029 [US3] Render flat all-files projections with directory context in grid and list modes in `app/lib/screens/gallery_screen.dart`
- [X] T030 [US3] Preserve current folder path while all-files mode is active and restore it when returning to folder grouping in `app/lib/screens/gallery_screen.dart`
- [X] T031 [US3] Update file card/list metadata to distinguish duplicate filenames by visible path context in `app/lib/widgets/gallery/file_tile.dart` and `app/lib/widgets/gallery/file_row.dart`
- [X] T032 [US3] Run User Story 3 tests with `cd app && flutter test test/gallery/gallery_view_model_test.dart test/gallery/gallery_view_modes_test.dart`

**Checkpoint**: Folder/all-files mode switching is functional and independently testable.

---

## Phase 6: User Story 4 - Continue Loading While Scrolling (Priority: P4)

**Goal**: Users get automatic scroll-down-to-load behavior in grid, list, folder, and all-files modes without next/previous page buttons.

**Independent Test**: Use more files than one page, scroll near the bottom in each mode, and verify additional files append with a bottom loading indicator.

### Tests for User Story 4

- [X] T033 [P] [US4] Add failing provider or widget test for load-more trigger preserving existing `offset`/`limit` behavior in `app/test/gallery/gallery_view_modes_test.dart`
- [X] T034 [P] [US4] Add failing widget test for bottom load-more indicator in list and grid modes in `app/test/gallery/gallery_view_modes_test.dart`

### Implementation for User Story 4

- [X] T035 [US4] Verify and adjust `_onScroll` load-more threshold for both `SliverGrid` and `SliverList` layouts in `app/lib/screens/gallery_screen.dart`
- [X] T036 [US4] Render bottom loading indicator consistently for grid and list modes when `isLoadingMore` is true in `app/lib/screens/gallery_screen.dart`
- [X] T037 [US4] Reset pagination through existing `FileListNotifier` reload paths when search, tags, type, grouping mode, or folder path changes in `app/lib/providers/file_list_provider.dart` and `app/lib/screens/gallery_screen.dart`
- [X] T038 [US4] Ensure no manual next/previous page controls are added and document loaded/visible folder counts only in `app/lib/screens/gallery_screen.dart`
- [X] T039 [US4] Run User Story 4 tests with `cd app && flutter test test/gallery/gallery_view_modes_test.dart`

**Checkpoint**: Infinite scroll behavior works across all Phase 1 gallery modes.

---

## Phase 7: Route State Integration

**Purpose**: Preserve gallery view mode, grouping mode, and folder path through `/vault` query parameters after core UX stories work.

- [X] T040 Add `initialViewMode`, `initialGroupingMode`, and `initialFolderPath` constructor fields to `GalleryScreen` in `app/lib/screens/gallery_screen.dart`
- [X] T041 Update `onRouteStateChanged` callback shape to include `view`, `group`, and `path` values in `app/lib/screens/gallery_screen.dart`
- [X] T042 Parse `view`, `group`, and `path` query parameters for `/vault` in `app/lib/router/app_router.dart`
- [X] T043 Preserve existing `q`, `type`, and `tags` query parameters while adding `view`, `group`, and `path` to generated `/vault` URLs in `app/lib/router/app_router.dart`
- [X] T044 Add route-state widget/helper regression tests for refresh-safe query state in `app/test/gallery/gallery_view_model_test.dart` and `app/test/gallery/gallery_view_modes_test.dart`
- [X] T045 Run route-state tests with `cd app && flutter test test/gallery/gallery_view_model_test.dart test/gallery/gallery_view_modes_test.dart`

**Checkpoint**: `/vault` query state round-trips existing filters plus view/group/path state.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, formatting, and Phase 2 documentation.

- [X] T046 [P] Document Phase 2 backend follow-up scope in `specs/007-gallery-view-modes/contracts/gallery-ui-contract.md`
- [X] T047 [P] Update manual validation notes in `specs/007-gallery-view-modes/quickstart.md` if implementation behavior differs from the planned scenarios
- [X] T048 Run Dart formatter for changed app files with `cd app && dart format lib test/gallery`
- [X] T049 Run focused gallery tests with `cd app && flutter test test/gallery`
- [X] T050 Run Flutter analysis with `cd app && flutter analyze`
- [X] T051 Verify no backend files, submodule files, `.data/` runtime state, secrets, generated tokens, or local database files are included in the final diff with `git status --short`
- [X] T052 Record manual smoke-test results for folder browsing, grid/list toggle, all-files mode, route refresh, and scroll-down-to-load in `specs/007-gallery-view-modes/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup and blocks every user story.
- **User Story 1 (Phase 3)**: Depends on Foundational and is the MVP.
- **User Story 2 (Phase 4)**: Depends on Foundational; should be implemented after US1 in this repo because list mode reuses folder/file projection helpers and folder row/card semantics.
- **User Story 3 (Phase 5)**: Depends on Foundational; should be implemented after US1 and US2 so all-files mode can reuse both projection and list/grid rendering.
- **User Story 4 (Phase 6)**: Depends on Foundational; should be validated after US1-US3 so scroll-down-to-load is checked in every visible mode.
- **Route State Integration (Phase 7)**: Depends on US1-US4 because it must preserve all final view states.
- **Polish (Phase 8)**: Depends on desired stories and route state completion.

### User Story Dependencies

- **US1 Browse Files By Folder**: MVP; no dependency on other stories after Foundational.
- **US2 Grid/List Views**: Can start after Foundational but is simpler after US1 because it reuses folder entries and file projections.
- **US3 All Files With Or Without Directories**: Can start after Foundational but should follow US1/US2 to reuse controls and row/card rendering.
- **US4 Continue Loading While Scrolling**: Can start after Foundational but must be verified after each visible mode exists.

### Within Each User Story

- Write focused tests before implementation tasks where practical.
- Implement helper/model logic before screen integration.
- Implement widgets before wiring them into `GalleryScreen`.
- Run the story-specific test command before marking the story complete.

---

## Parallel Opportunities

- T004 and T005 can run in parallel because both add tests to the same file only if coordinated; otherwise run sequentially.
- T010 and T011 can run in parallel because one targets helper behavior and one targets widget behavior.
- T012 and T013 can run in parallel because they create different widget files.
- T019 and T020 can run in parallel because they cover different widget expectations.
- T021 can run while T022 is being prepared, but screen integration must wait for `file_row.dart`.
- T026 and T027 can run in parallel because one targets helper projection behavior and one targets widget behavior.
- T033 and T034 can run in parallel because they cover separate load-more expectations.
- T046 and T047 can run in parallel because they update different Spec Kit docs.

## Parallel Example: User Story 1

```bash
# Helper projection tests and widget tests can be prepared separately:
Task: "T010 [US1] Add failing helper tests for root folders, nested folders, direct child files, malformed paths, and empty root path behavior in app/test/gallery/gallery_view_model_test.dart"
Task: "T011 [US1] Add failing widget tests for folder cards/rows, opening a folder, and using the up/back folder control in app/test/gallery/gallery_view_modes_test.dart"

# Folder widgets can be created separately:
Task: "T012 [US1] Create folder card widget for grid mode in app/lib/widgets/gallery/folder_tile.dart"
Task: "T013 [US1] Create folder row widget for list-compatible folder rendering in app/lib/widgets/gallery/folder_row.dart"
```

## Parallel Example: User Story 2

```bash
Task: "T019 [US2] Add failing widget tests for grid/list toggle preserving folder path and filters in app/test/gallery/gallery_view_modes_test.dart"
Task: "T020 [US2] Add failing widget tests for file rows showing name, path/type context, size, and modified date in app/test/gallery/gallery_view_modes_test.dart"
Task: "T021 [US2] Create compact file row widget in app/lib/widgets/gallery/file_row.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup.
2. Complete Phase 2: Foundational helpers and tests.
3. Complete Phase 3: folder browsing.
4. Run `cd app && flutter test test/gallery/gallery_view_model_test.dart test/gallery/gallery_view_modes_test.dart`.
5. Stop and manually validate folder browsing before adding list/all-files modes.

### Incremental Delivery

1. Add folder browsing MVP.
2. Add list mode without changing backend behavior.
3. Add all-files/folder grouping toggle.
4. Validate scroll-down-to-load across all modes.
5. Add route-state preservation.
6. Run focused tests, formatting, and `flutter analyze`.

### Phase 2 Backend Follow-Up

Phase 2 backend work is not part of this implementation task list. If folder completeness or offset pagination becomes a blocking UX issue, create a separate Spec Kit feature for Engram cursor pagination and folder-aware browse endpoints before editing `engram/backend/`.

## Notes

- Phase 1 must not edit `engram/`, `reliquary/`, or `synapse/` implementation files.
- Folder counts must not be presented as authoritative global totals unless all relevant pages are loaded.
- Keep UI controls icon-first and compact; avoid adding explanatory in-app text for feature behavior.
- Every completed implementation task must be marked `[X]` before `/speckit-implement` reports completion.
