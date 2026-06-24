# Tasks: Frontend Performance Optimization

**Input**: Design documents from `/specs/005-frontend-performance/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md

**Tests**: Include focused widget tests and `flutter analyze` checkpoints for changed behavior.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Environment Verification)

**Purpose**: Confirm the development environment and baseline behavior before making changes.

- [X] T001 Run baseline verification: `cd app && flutter analyze` and `cd app && flutter test` pass on `main`

---

## Phase 2: Foundational (Shared Helpers & Selectors)

**Purpose**: Add lightweight helpers and selectors that multiple user stories will use.

**⚠️ CRITICAL**: Complete this phase before starting user story implementation.

- [X] T002 [P] Add `FileListState` helper getters (`isLoading`, `hasMore`) in `app/lib/providers/file_list_provider.dart`
- [X] T003 [P] Add `UploadState` helper getter (`isUploading`) in `app/lib/providers/upload_provider.dart`
- [X] T004 Create `PreviewCache` helper in `app/lib/utils/preview_cache.dart` for memoizing presigned URL and PDF byte futures
- [X] T005 Add widget test harness and mock services needed for rebuild-boundary tests in `app/test/`

**Checkpoint**: Foundation ready - `flutter analyze` clean; helper utilities compile.

---

## Phase 3: User Story 1 - Smooth Gallery Scrolling (Priority: P1) 🎯 MVP

**Goal**: Make the gallery mount and scroll smoothly by enabling viewport recycling and fine-grained state watches.

**Independent Test**: Gallery with many files scrolls without visible frame drops; only visible tiles are built.

### Tests for User Story 1

- [ ] T006 [P] [US1] Add widget test in `app/test/gallery/gallery_scroll_test.dart` verifying `SliverGrid` builds only visible children
- [X] T007 [P] [US1] Add widget test in `app/test/gallery/file_tile_test.dart` verifying `FileTile` uses `ValueKey(file.id)` and preserves state

### Implementation for User Story 1

- [X] T008 [P] [US1] Add `ValueKey(file.id)` to `FileTile` in `app/lib/widgets/gallery/file_tile.dart`
- [X] T009 [P] [US1] Add `cacheWidth`/`cacheHeight` to thumbnail `Image.network` in `app/lib/widgets/gallery/file_tile.dart`
- [X] T010 [P] [US1] Add `AutomaticKeepAliveClientMixin` to `FileTile` in `app/lib/widgets/gallery/file_tile.dart` to reduce re-fetch when scrolling back
- [X] T011 [US1] Replace `SingleChildScrollView` + `GridView.builder(shrinkWrap: true)` with `CustomScrollView` + `SliverGrid` in `app/lib/screens/gallery_screen.dart`
- [X] T012 [US1] Use `ref.watch(fileListProvider.select((s) => s.files))` for grid, `select((s) => s.isLoading)` for loader, and `select((s) => s.hasMore)` for pagination button in `app/lib/screens/gallery_screen.dart`
- [X] T013 [US1] Move `reliquary` service read out of per-tile build or pass it once to `FileTile` in `app/lib/screens/gallery_screen.dart`
- [X] T014 [US1] Run `cd app && flutter analyze` and `cd app && flutter test` after gallery changes

**Checkpoint**: User Story 1 fully functional and testable independently.

---

## Phase 4: User Story 2 - Stable File Previews (Priority: P2)

**Goal**: Prevent image and PDF previews from re-fetching on every parent rebuild.

**Independent Test**: Open file detail for image/PDF, trigger a parent rebuild, and confirm the preview does not reload.

### Tests for User Story 2

- [ ] T015 [P] [US2] Add widget test in `app/test/file_detail/image_preview_test.dart` asserting presigned URL is requested only once across rebuilds
- [ ] T016 [P] [US2] Add widget test in `app/test/file_detail/pdf_preview_test.dart` asserting PDF bytes are downloaded only once across rebuilds

### Implementation for User Story 2

- [X] T017 [US2] Memoize presigned image URL future in `ImagePreview` state in `app/lib/widgets/file_detail/image_preview.dart`
- [X] T018 [US2] Add `cacheWidth`/`cacheHeight` capped to screen size in `ImagePreview` in `app/lib/widgets/file_detail/image_preview.dart`
- [X] T019 [US2] Memoize PDF bytes future in `PdfPreview` state in `app/lib/widgets/file_detail/pdf_preview.dart`
- [X] T020 [US2] Use `PreviewCache` for image presigned URLs and PDF bytes in `app/lib/widgets/file_detail/image_preview.dart` and `app/lib/widgets/file_detail/pdf_preview.dart`
- [X] T021 [US2] Run `cd app && flutter analyze` and `cd app && flutter test` after preview changes

**Checkpoint**: User Stories 1 and 2 both work independently.

---

## Phase 5: User Story 3 - Responsive Upload Screen (Priority: P2)

**Goal**: Localize drag-hover and upload-progress state so the whole screen does not rebuild.

**Independent Test**: Drag files over drop zone and upload files; hover/progress updates are smooth and do not rebuild the header or unrelated tiles.

### Tests for User Story 3

- [ ] T022 [P] [US3] Add widget test in `app/test/upload/upload_drop_zone_test.dart` verifying hover state rebuilds only the drop zone
- [ ] T023 [P] [US3] Add widget test in `app/test/upload/upload_screen_test.dart` verifying progress update for one file does not rebuild the entire list

### Implementation for User Story 3

- [X] T024 [P] [US3] Add `ValueKey(task.id)` to `UploadFileTile` in `app/lib/widgets/upload/upload_file_tile.dart`
- [X] T025 [US3] Extract drag hover state into `UploadDropZone` widget in `app/lib/widgets/upload/upload_drop_zone.dart`
- [X] T026 [US3] Replace inline drop zone in `UploadScreen` with new `UploadDropZone` in `app/lib/screens/upload_screen.dart`
- [X] T027 [US3] Use `ref.watch(uploadProvider.select((s) => s.selectedFiles))` for list and `select((s) => s.isUploading)` for header action in `app/lib/screens/upload_screen.dart`
- [X] T028 [US3] Run `cd app && flutter analyze` and `cd app && flutter test` after upload changes

**Checkpoint**: User Stories 1, 2, and 3 all work independently.

---

## Phase 6: User Story 4 - Efficient Admin & Settings Screens (Priority: P3)

**Goal**: Remove unnecessary rebuilds and recomputation in admin search, gallery filter overlay, and settings theme cards.

**Independent Test**: Admin search and filter overlay typing are responsive; gallery does not rebuild on draft filter changes.

### Tests for User Story 4

- [ ] T029 [P] [US4] Add widget test in `app/test/admin_screen_test.dart` verifying filtered user list is memoized across keystrokes
- [ ] T030 [P] [US4] Add widget test in `app/test/gallery/filter_overlay_test.dart` verifying gallery does not rebuild on draft filter changes

### Implementation for User Story 4

- [X] T031 [P] [US4] Add `ValueKey(user['username'])` to `_UserTile` in `app/lib/screens/admin_screen.dart`
- [X] T032 [US4] Memoize `_filteredUsers` with `useMemoized` (or equivalent) keyed by `_query` and user list in `app/lib/screens/admin_screen.dart`
- [X] T033 [P] [US4] Add `ValueKey(tag)` to tag chips in `app/lib/screens/file_detail_screen.dart`
- [X] T034 [P] [US4] Add `ValueKey(setting.name)` to theme setting cards in `app/lib/screens/settings_screen.dart`
- [X] T035 [US4] Move draft filter state from `GalleryScreen` into `FilterDropdownPanel` in `app/lib/widgets/gallery/filter_dropdown_panel.dart`
- [X] T036 [US4] Use `ref.watch(appAuthProvider.select((s) => s.isLoggedIn))` in `app/lib/router/app_router.dart` instead of watching full async service providers
- [X] T037 [US4] Run `cd app && flutter analyze` and `cd app && flutter test` after admin/settings/router changes

**Checkpoint**: All user stories independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final verification and cleanup across all stories.

- [X] T038 [P] Remove unused imports and dead code introduced by refactoring in `app/lib/`
- [X] T039 [P] Add documentation comments to `PreviewCache` and new helper getters in `app/lib/`
- [X] T040 Run full `cd app && flutter analyze` and `cd app && flutter test` across the feature
- [ ] T041 Run quickstart validation scenarios from `specs/005-frontend-performance/quickstart.md`
- [X] T042 Verify no generated runtime state, secrets, or `.data/` content is included in the final diff

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories
- **User Stories (Phase 3-6)**: Depend on Foundational phase
  - Execute in priority order: US1 (P1) → US2 (P2) → US3 (P2) → US4 (P3)
  - US2 and US3 can proceed in parallel after US1 if desired
- **Polish (Phase 7)**: Depends on all desired user stories

### User Story Dependencies

- **User Story 1 (P1)**: No dependencies on other stories; MVP
- **User Story 2 (P2)**: Depends on `PreviewCache` helper from Phase 2
- **User Story 3 (P2)**: Depends on helper getters from Phase 2
- **User Story 4 (P3)**: Depends on helper getters from Phase 2; independent of other stories

### Within Each User Story

- Tests are written before implementation where practical
- Helpers/selectors before screen/widget changes
- Screen/widget changes before verification

### Parallel Opportunities

- All Setup and Foundational tasks marked [P] can run in parallel
- US2 and US3 can be worked in parallel after US1
- Tests within each story marked [P] can run in parallel
- Widget key additions across different files (T008, T024, T031, T033, T034) can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch tests and key implementation tasks in parallel:
Task: "T006 Add widget test verifying SliverGrid builds only visible children"
Task: "T007 Add widget test verifying FileTile ValueKey and state preservation"
Task: "T008 Add ValueKey(file.id) to FileTile"
Task: "T009 Add cacheWidth/cacheHeight to FileTile thumbnail"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational helpers/selectors
3. Complete Phase 3: User Story 1 (gallery scroll performance)
4. **STOP and VALIDATE**: `flutter analyze` clean, gallery scroll test passes
5. Demo the smooth gallery scroll

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. US1 → Gallery scroll smooth → Validate
3. US2 → Previews stable → Validate
4. US3 → Upload screen responsive → Validate
5. US4 → Admin/settings efficient → Validate
6. Polish → Full test suite and quickstart validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Developer A: US1 (gallery)
3. Developer B: US2 (previews) and US3 (upload) in parallel after US1
4. Developer C: US4 (admin/settings/router)
5. Integrate and run full verification

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify `flutter analyze` is clean after each task group
- Commit after each task or logical group
- Stop at any checkpoint to validate the story independently
- Avoid cross-story dependencies that break independence
