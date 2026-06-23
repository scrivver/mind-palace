# Tasks: Frontend Codebase Refactoring

**Input**: Design documents from `specs/004-frontend-refactoring/`

**Prerequisites**: plan.md (required), spec.md, research.md, data-model.md, quickstart.md

**Tests**: This feature is a no-regression refactoring. Tests are added in Phase 5 to cover extracted components. All existing tests must continue to pass after every phase.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to
- Include exact file paths in descriptions

## Path Conventions

- **Root Flutter app**: `app/lib/`, `app/test/`
- **Root infrastructure**: `infra/`, `bin/`, `shells/`, `.data/` for runtime state only
- **Docs/spec artifacts**: `specs/004-frontend-refactoring/`
- All paths are relative to repository root `/home/chunhou/Dev/mind-palace`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize new dependencies and directory structure.

- [x] T001 Add `flutter_riverpod`, `go_router` to `app/pubspec.yaml` dependencies
- [x] T002 [P] Create `app/lib/utils/` directory with `format.dart` and `logger.dart` stubs
- [x] T003 [P] Create `app/lib/providers/` directory with `service_providers.dart`, `theme_provider.dart`, `file_list_provider.dart`, `upload_provider.dart` stubs
- [x] T004 [P] Create `app/lib/router/` directory with `app_router.dart` stub
- [x] T005 [P] Create `app/lib/widgets/gallery/`, `app/lib/widgets/upload/`, `app/lib/widgets/file_detail/` directories
- [x] T006 Run `cd app && flutter pub get` to install new dependencies and verify `flutter analyze` passes

---

## Phase 2: Foundational — Utilities & Deduplication (Blocking Prerequisites)

**Purpose**: Core utility modules and duplicated code consolidation that MUST be complete before screen splitting or DI migration.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete. These tasks touch utility code and inline functions across multiple screens without altering their behavior.

- [x] T007 [P] Create `FormatUtils.formatBytes()` in `app/lib/utils/format.dart` with `int decimals` parameter — port logic from existing `formattedSize` getters in `models/engram_file.dart` (line 64), `models/file_item.dart` (line 44), `upload_screen.dart` (line 713), `status_screen.dart` (line 226)
- [x] T008 [P] Create `FormatUtils.relativeTime()` in `app/lib/utils/format.dart` — port logic from `_relativeTime` in `gallery_screen.dart` (line 871) and `file_detail_screen.dart` (line 600); standardize on "Just now" / "Xm ago" / "Xh ago" / "Xd ago"
- [x] T009 [P] Create `iconForMime(String mimeType)` top-level function in `app/lib/utils/format.dart` — port logic from `_iconForMime` in `gallery_screen.dart` (line 883) and `file_detail_screen.dart` (line 573)
- [x] T010 [P] Create `LoggerService` class in `app/lib/utils/logger.dart` with `info()`, `warning()`, `error()`, `debug()` methods wrapping `dart:developer` `log()`
- [x] T011 [US3] Replace inline `formattedSize` / `_formatBytes` / `formatBytes` in `gallery_screen.dart`, `file_detail_screen.dart`, `upload_screen.dart`, `status_screen.dart`, `models/engram_file.dart`, `models/file_item.dart` with `FormatUtils.formatBytes()` import
- [x] T012 [US3] Replace inline `_relativeTime` in `gallery_screen.dart` and `file_detail_screen.dart` with `FormatUtils.relativeTime()` import
- [x] T013 [US3] Replace inline `_iconForMime` in `gallery_screen.dart` and `file_detail_screen.dart` with `iconForMime()` import
- [x] T014 [US3] Consolidate auth config probing: add `ServerUrlStore.validateUrl(String url)` static method in `app/lib/services/server_url_store.dart` that probes `GET /api/auth/config`; update `main.dart`, `settings_screen.dart`, and `server_setup_screen.dart` to call this unified method

**Checkpoint**: Foundation ready — no duplicated utilities remain. Run `flutter analyze` to confirm zero errors.

---

## Phase 3: User Story 2 — Extensibility: DI & Navigation (Priority: P1)

**Goal**: Replace manual service wiring in `HomePage` with Riverpod DI container and index-based navigation with `go_router`. All screens still work identically.

**Independent Test**: The app starts, authenticates, and navigates to all screens correctly. A developer can add a new screen route without modifying `main.dart`.

- [x] T015 [P] [US2] Create Riverpod service providers in `app/lib/providers/service_providers.dart`: `serverUrlStoreProvider`, `authServiceProvider`, `engramServiceProvider`, `reliquaryServiceProvider` — wrap existing service classes with factory constructors
- [x] T016 [P] [US2] Create `themeServiceProvider` in `app/lib/providers/theme_provider.dart` wrapping existing `ThemeService` and its `Stream<ThemeSetting>`
- [x] T017 [US2] Create `app/lib/router/app_router.dart` with `GoRouter` using `ShellRoute` wrapping `Sidebar` + body, with routes for `/vault`, `/status`, `/settings`, `/upload`, `/file/:fileId`, `/setup`, `/login` per data-model.md route definitions
- [x] T018 [US2] Create `AppShell` widget in `app/lib/widgets/app_shell.dart` that renders `Sidebar` alongside a child body — used as the `ShellRoute` builder
- [x] T019 [US2] Migrate `main.dart`: wrap `MindPalaceApp` in `ProviderScope`; replace `_navIndex`-based `_buildScreen()` with `MaterialApp.router` using the `GoRouter` from step T017; remove inline service instantiation from `_HomePageState`; keep only app entry, theme stream subscription, and gate logic
- [x] T020 [P] [US2] Create `fileListProvider` in `app/lib/providers/file_list_provider.dart` with `FileListNotifier` managing `FileListState` (files, loading, search query, filter, pagination, hasMore)
- [x] T021 [P] [US2] Create `uploadProvider` in `app/lib/providers/upload_provider.dart` with `UploadNotifier` managing `UploadState` (queue, uploading status, progress, retry)
- [x] T022 [US2] Replace `refreshTrigger` int-key pattern in `main.dart` and screen callbacks with `ref.invalidate(fileListProvider)` — remove `refreshTrigger` state and `onFileDeleted` callback wiring from `HomePage`

**Checkpoint**: US2 functional — app starts via Riverpod + go_router. Run `flutter analyze` and manual navigation smoke test.

---

## Phase 4: User Story 1 — Maintainability: Screen Splitting & HomePage Cleanup (Priority: P1)

**Goal**: Split 3 oversized screens into focused widget files, extract shared components, and strip `HomePage` of remaining responsibilities. Each screen must render identically to pre-refactoring.

**Independent Test**: All screens load and function identically. `main.dart` (`HomePage`) is at least 40% smaller. `flutter analyze` reports zero errors.

### Gallery Screen (1097 lines → split into widgets/gallery/)

- [x] T023 [P] [US1] Extract `_FileTile` (with its `_FileTileState`) from `app/lib/screens/gallery_screen.dart` into `app/lib/widgets/gallery/file_tile.dart` — export as public `FileTile` with same parameters
- [x] T024 [P] [US1] Extract `_FilterDropdownPanel` (with `_FilterDropdownPanelState`) from `gallery_screen.dart` into `app/lib/widgets/gallery/filter_dropdown_panel.dart` — export as public `FilterDropdownPanel`
- [x] T025 [P] [US1] Extract `_QuickFilterChip` from `gallery_screen.dart` into `app/lib/widgets/gallery/quick_filter_chip.dart` — export as public `QuickFilterChip`
- [x] T026 [US1] Refactor `app/lib/screens/gallery_screen.dart`: import extracted widgets; consume `fileListProvider` via Riverpod `ref.watch`/`ref.read` instead of local `setState` for file list state, search, filter, pagination

### Upload Screen (734 lines → split into widgets/upload/)

- [x] T027 [P] [US1] Extract `_UploadFileTile` from `app/lib/screens/upload_screen.dart` into `app/lib/widgets/upload/upload_file_tile.dart` — export as public `UploadFileTile`
- [x] T028 [P] [US1] Extract `_UploadProgress` from `upload_screen.dart` into `app/lib/widgets/upload/upload_progress.dart` — export as public `UploadProgress`
- [x] T029 [P] [US1] Extract `_DashedBorderPainter` from `upload_screen.dart` into `app/lib/widgets/upload/dashed_border_painter.dart` — export as public `DashedBorderPainter`
- [x] T030 [US1] Refactor `app/lib/screens/upload_screen.dart`: import extracted widgets; consume `uploadProvider` via Riverpod for queue management; delegate upload orchestration to provider

### File Detail Screen (685 lines → split into widgets/file_detail/)

- [x] T031 [P] [US1] Extract image preview section from `app/lib/screens/file_detail_screen.dart` into `app/lib/widgets/file_detail/image_preview.dart` — export as public `ImagePreview`
- [x] T032 [P] [US1] Extract PDF preview section from `file_detail_screen.dart` into `app/lib/widgets/file_detail/pdf_preview.dart` — export as public `PdfPreview`
- [x] T033 [P] [US1] Extract extracted text dialog from `file_detail_screen.dart` into `app/lib/widgets/file_detail/extracted_text_dialog.dart` — export as `showExtractedTextDialog(BuildContext, String)` function
- [x] T034 [P] [US1] Extract `_DeleteDialog` from `file_detail_screen.dart` into `app/lib/widgets/file_detail/delete_dialog.dart` — export as public `showDeleteDialog(BuildContext, String filename)` function
- [x] T035 [US1] Refactor `app/lib/screens/file_detail_screen.dart`: import extracted widgets; use `ref.read(reliquaryServiceProvider)` instead of constructor-injected service

### Strip HomePage God Class

- [x] T036 [US1] Strip `main.dart` `HomePage` widget: remove remaining service wiring (all services now obtained via Riverpod providers); remove auth gate routing (now handled by `GoRouter` redirects); remove `_navIndex` and `_buildScreen()` (now handled by `GoRouter`); keep only `MindPalaceApp`, theme stream subscription, `ProviderScope`, and `MaterialApp.router`

**Checkpoint**: US1 functional — all screens split, HomePage reduced. Run `flutter analyze` and complete manual smoke test of all navigation paths.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Tests, cleanup, and final verification.

- [x] T037 [P] Create app smoke test `app/test/widget_test.dart` that verifies `MindPalaceApp` renders and `flutter test` passes
- [x] T038 [P] Create widget test for `FileTile` in `app/test/gallery/file_tile_test.dart`
- [x] T039 [P] Create widget test for `UploadFileTile` in `app/test/upload/upload_file_tile_test.dart`
- [x] T040 Remove unused imports across all modified files; run `dart format .` in `app/`
- [x] T041 Run `cd app && flutter analyze` — confirm zero errors and zero warnings
- [x] T042 Run `cd app && flutter test` — confirm all existing and new tests pass
- [x] T043 Run quickstart.md validation scenarios 3–6 (manual smoke test) to confirm zero regression
- [x] T044 Verify no generated runtime state, secrets, or `.data/` content are included in the final diff

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories
- **US2 (Phase 3)**: Depends on Foundational — BLOCKS US1
- **US1 (Phase 4)**: Depends on Phase 3 (needs Riverpod providers and go_router in place before screen splits can consume them)
- **Polish (Phase 5)**: Depends on Phase 4 completion

### User Story Dependencies

- **US1 — Maintainability (P1)**: Depends on US2 (Riverpod + go_router) for screen migration to providers
- **US2 — Extensibility (P1)**: Depends on Phase 2 (dedup utilities are needed by providers)
- **US3 — Eliminate Duplication (P2)**: Handled entirely in Foundational phase (blocks everything)

### Within Each Phase

- Models/utilities before migration
- Extraction before refactoring the host file
- Verification (`flutter analyze`) after each logical group

### Parallel Opportunities

- All Phase 1 Setup tasks marked [P] can run in parallel
- All Phase 2 Foundational tasks marked [P] can run in parallel
- US2 (Phase 3): T015, T016 (providers) can run in parallel; T020, T021 (state providers) in parallel
- US1 Gallery: T023, T024, T025 (widget extraction) in parallel
- US1 Upload: T027, T028, T029 (widget extraction) in parallel
- US1 File Detail: T031, T032, T033, T034 (widget extraction) in parallel
- Phase 5: T037, T038, T039 (tests) can run in parallel

---

## Parallel Example: Phase 4 — User Story 1 (Screen Splitting)

```bash
# Launch all Gallery widget extractions together:
Task: "Extract _FileTile to widgets/gallery/file_tile.dart"
Task: "Extract _FilterDropdownPanel to widgets/gallery/filter_dropdown_panel.dart"
Task: "Extract _QuickFilterChip to widgets/gallery/quick_filter_chip.dart"

# Launch all Upload widget extractions together:
Task: "Extract _UploadFileTile to widgets/upload/upload_file_tile.dart"
Task: "Extract _UploadProgress to widgets/upload/upload_progress.dart"
Task: "Extract _DashedBorderPainter to widgets/upload/dashed_border_painter.dart"

# Launch all File Detail widget extractions together:
Task: "Extract image preview to widgets/file_detail/image_preview.dart"
Task: "Extract PDF preview to widgets/file_detail/pdf_preview.dart"
Task: "Extract text dialog to widgets/file_detail/extracted_text_dialog.dart"
Task: "Extract delete dialog to widgets/file_detail/delete_dialog.dart"
```

---

## Implementation Strategy

### MVP First (US2 — Extensibility)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (dedup — quick wins, immediate value)
3. Complete Phase 3: US2 (Riverpod + go_router — enables all further work)
4. **STOP and VALIDATE**: App runs with Riverpod DI and go_router navigation, no regression

### Incremental Delivery

1. **Phase 1 + 2** → No duplicated utilities; foundation ready
2. **Phase 3 (US2)** → Extensible DI + proper routing (MVP!)
3. **Phase 4 (US1)** → Manageable file sizes per screen; HomePage no longer a god class
4. **Phase 5** → Test coverage, cleanup

### Parallel Team Strategy

With multiple developers:
1. Phase 1 + 2 → any developer
2. Once Phase 2 done:
   - Developer A: US2 (Phase 3) — Riverpod providers + go_router
   - Developer B: Phase 4 Gallery — widget extraction (awaits Phase 3 for provider wiring)
3. After Phase 3:
   - Developer A: Upload widget extraction
   - Developer B: File Detail widget extraction
   - Together: HomePage strip
