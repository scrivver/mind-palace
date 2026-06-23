# Implementation Plan: Frontend Codebase Refactoring

**Branch**: `` (no feature branch created yet) | **Date**: 2026-06-23 | **Spec**: [spec.md](./spec.md)

**Input**: User request to refactor the Flutter frontend codebase which has grown too large.

## Summary

Refactor the Mind Palace Flutter app (`app/lib/`) to eliminate the `HomePage` god class in `main.dart`, adopt a state management / DI library (Riverpod or Provider), replace index-based navigation with `go_router`, split 3 oversized screens (1097, 734, 685 lines), consolidate 5 instances of duplicated utility code, and add centralized error handling — all while preserving zero behavioral regression.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x

**Primary Dependencies**: `flutter_riverpod` (state management + DI), `go_router` (navigation), existing `dio`, `shared_preferences`, `flutter_secure_storage`, `url_launcher`, `desktop_drop`, `file_picker`, `flutter_appauth`, `pdfrx`. No new runtime dependencies beyond the two additions.

**Storage**: Unchanged — client-side `shared_preferences` for theme; `flutter_secure_storage` for tokens.

**Testing**: `cd app && flutter analyze` (static analysis), `cd app && flutter test` (unit/widget tests). Existing tests must continue to pass; new tests added for refactored modules.

**Target Platform**: Linux desktop (primary), Flutter web (secondary). Same as current.

**Project Type**: Flutter desktop/web app — pure refactoring, no new features.

**Performance Goals**: No regression in screen rendering time, navigation speed, or theme switching latency.

**Constraints**:
- Zero visual or behavioral change — all refactoring must be invisible to the user.
- Must preserve the conditional import pattern for web/native platform abstractions.
- Each refactoring step must leave the app in a compilable and runnable state.
- Independent, verifiable steps — no mega-refactors that are hard to review or roll back.

**Scale/Scope**: 34 Dart source files (plus platform variants), ~6,400 lines across `app/lib/`. All files will be touched. ~2 new packages added.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: Verification uses `cd app && flutter analyze` and `cd app && flutter test` from the root `nix develop` environment. Each step is verified before proceeding. `start-app` launcher used for manual regression checks.
- **Component boundaries**: Changes are limited to `app/` only. No changes to `reliquary/`, `engram/`, `synapse/`, or `infra/`. No submodule work.
- **Contract-driven integration**: No API endpoint, event, queue, storage schema, or authentication contract changes. Theme persistence mechanism and token storage remain identical. No event-producing changes.
- **Verification proportional to change**: Flutter analysis (`flutter analyze`) after each step. Existing test suite (`flutter test`) must pass. Manual smoke test of key navigation paths (login → gallery → file detail → upload → settings) after major structural changes. Screenshots not required (no visual changes).
- **State and secret hygiene**: No new runtime state, environment variables, secrets, or migrations. Auth tokens continue using `flutter_secure_storage`; theme continues using `shared_preferences`/`localStorage`.

## Project Structure

### Documentation (this feature)

```text
specs/004-frontend-refactoring/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 — technology choices (DI, router, logger)
├── data-model.md        # Phase 1 — refactored module boundaries and interfaces
├── quickstart.md        # Phase 1 — validation guide
└── contracts/           # (empty — no new API contracts)
```

### Source Code (repository root)

The refactoring touches only `app/`, and only the files listed below:

```text
app/
  lib/
    main.dart                        # GOD CLASS — extract HomePage responsibilities
                                     #   => Remove: service instantiation, navigation, auth gate
                                     #   => Keep: app entry, theme provider setup
    services/
      server_url_store.dart          # Consolidate auth config probing here
    screens/
      gallery_screen.dart            # 1097 lines — split into widgets/gallery/*
      upload_screen.dart             # 734 lines — split into widgets/upload/*
      file_detail_screen.dart        # 685 lines — split into widgets/file_detail/*
    utils/                           # NEW directory
      format.dart                    # formatBytes, relativeTime, iconForMime
      logger.dart                    # Centralized logging service
    widgets/
      gallery/                       # EXTRACTED from gallery_screen.dart
        file_tile.dart               # _FileTile
        filter_dropdown_panel.dart   # _FilterDropdownPanel
        quick_filter_chip.dart       # _QuickFilterChip
      upload/                        # EXTRACTED from upload_screen.dart
        upload_file_tile.dart        # _UploadFileTile
        upload_progress.dart         # _UploadProgress
        dashed_border_painter.dart   # _DashedBorderPainter
      file_detail/                   # EXTRACTED from file_detail_screen.dart
        image_preview.dart           # _buildImagePreview section
        pdf_preview.dart             # _buildPdfPreview section
        extracted_text_dialog.dart   # Extracted text dialog
        delete_dialog.dart           # _DeleteDialog
      sidebar.dart                   # UNCHANGED
      web_drop_zone.dart             # UNCHANGED
      web_drop_zone_impl.dart        # UNCHANGED
      web_drop_zone_stub.dart        # UNCHANGED
      drop_target_stub.dart          # UNCHANGED
    router/                          # NEW directory
      app_router.dart                # go_router configuration replacing _navIndex
    providers/                       # NEW directory
      service_providers.dart         # Riverpod providers for AuthService, EngramService, etc.
      theme_provider.dart            # Riverpod provider wrapping ThemeService
      file_list_provider.dart        # Riverpod provider for gallery file list state
      upload_provider.dart           # Riverpod provider for upload queue state
  test/
    settings_screen_test.dart        # EXISTING — must continue to pass
    auth_service_test.dart           # EXISTING — must continue to pass
    widget_test.dart                 # NEW — smoke test for refactored app shell
    gallery/                         # NEW
      file_tile_test.dart
    upload/                          # NEW
      upload_file_tile_test.dart
```

**Structure Decision**: Extract screens into dedicated widget subdirectories under `app/lib/widgets/{screen}/` to match the existing `widgets/` convention. New `utils/`, `router/`, and `providers/` directories follow standard Flutter project organization.

## Complexity Tracking

No constitution violations required.

---

## Phase 0: Research

### Unknowns from Technical Context

1. **DI / State management library** — Provider vs Riverpod vs BLoC vs GetIt. Which fits best for a ~6.4kLOC codebase with no existing state management?
2. **Navigation library** — `go_router` vs `Navigator 2.0` vs keeping manual index routing. Which works best with sidebar-driven navigation?
3. **Logging library** — `logging` (package), `logger`, or simple custom wrapper. What is the simplest adequate solution?
4. **Refactoring sequence** — What is the safe ordering of changes to keep the app compilable at every step?
5. **Riverpod compatibility** — Does Riverpod work with the conditional import pattern for platform services?

### Research Resolution

#### 1. DI / State Management

**Decision**: Use **Riverpod** (`flutter_riverpod` + `riverpod_annotation`).

**Rationale**: Riverpod provides compile-safe dependency injection without `BuildContext` dependency, supports code generation for less boilerplate, and integrates naturally with the existing service classes. It replaces both `HomePage`'s manual DI and `setState`-based state management simultaneously. Provider is simpler but couples to the widget tree; BLoC is too heavyweight for this codebase size (~6.4kLOC).

**Alternatives considered**:
- **Provider** — simpler but requires `BuildContext` for access and doesn't support autodispose or family modifiers as cleanly.
- **BLoC** — too formal and boilerplate-heavy for this codebase; would require event/state classes for every screen.
- **GetIt** — only solves DI, not state management; would still need a separate solution for reactive state.
- **GetX** — powerful but magical; implicit dependencies make refactoring harder to reason about.

#### 2. Navigation

**Decision**: Use **`go_router`**.

**Rationale**: `go_router` supports declarative routing with simple `ShellRoute` that wraps sidebar navigation. The sidebar pattern (Vault, Status, Settings, Upload) maps naturally to a `StatefulShellRoute`. Detail screen becomes a route with a file ID parameter. Back navigation and browser history work automatically.

**Alternatives considered**:
- **Navigator 2.0 raw** — too manual and verbose for the current routing needs.
- **Keep index-based routing** — option if go_router adds unacceptable complexity for a desktop app, but would not support future web deep-linking needs.

#### 3. Logging

**Decision**: Use Dart's built-in `dart:developer` `log()` for development and a simple `LoggerService` wrapper class.

**Rationale**: Adding a third-party logging package is unnecessary for this codebase size. The `LoggerService` wrapper provides a centralized point that can be replaced with a more sophisticated solution later if needed.

**Alternatives considered**:
- **`logging` package** — well-known but adds another dependency for simple use cases.
- **`logger` package** — pretty-printing is nice but unnecessary for a dev-focused app.

#### 4. Refactoring Sequence

**Decision**: Execute in the following order, with each step being independently verifiable:

1. **Create utility modules** (`utils/format.dart`, `utils/logger.dart`) — no behavioral change, pure addition.
2. **Extract duplicated code** — replace inline functions with utility imports.
3. **Add Riverpod and providers** — install `flutter_riverpod`, create providers wrapping existing services. App still uses old wiring pattern.
4. **Migrate navigation to go_router** — add `go_router`, create `ShellRoute` for sidebar, replace `_navIndex` and `_buildScreen()` in `HomePage`.
5. **Split gallery_screen.dart** — extract widgets to `widgets/gallery/*`, migrate to Riverpod for file list state.
6. **Split upload_screen.dart** — extract widgets to `widgets/upload/*`, create `UploadProvider`.
7. **Split file_detail_screen.dart** — extract widgets to `widgets/file_detail/*`.
8. **Strip HomePage god class** — after router and providers are in place, remove service wiring and theme management from `HomePage`. It becomes a simple shell.
9. **Add test coverage** — widget tests for extracted components, smoke test for app shell.
10. **Final cleanup** — remove unused imports, ensure `flutter analyze` is clean.

**Rationale**: Step 1-2 produce immediate value (no more duplicated code). Steps 3-4 enable steps 5-8. Step 8 is last because it depends on all previous steps. Each step leaves the app compilable and functional.

#### 5. Riverpod + Conditional Import Pattern

**Decision**: Riverpod works fine with conditional imports. Services like `AuthService` that use conditional exports (`export 'auth_service_web.dart' if (dart.library.io) 'auth_service_native.dart'`) remain unchanged. Providers simply `ref.read` these services as they exist today. No Riverpod-specific platform abstraction needed.

---

## Phase 1: Design & Contracts

### Data Model

See [data-model.md](./data-model.md) for full entity definitions.

Key entities:
- **Provider hierarchy**: Riverpod providers wrapping existing services (`authServiceProvider`, `engramServiceProvider`, `reliquaryServiceProvider`, `themeServiceProvider`)
- **Route definitions**: `go_router` `ShellRoute` with `Sidebar` as shell, `StatefulShellBranch` per screen
- **Utility functions**: `iconForMime(MimeType)`, `formatBytes(int)`, `relativeTime(DateTime)` — pure functions extracted to `utils/format.dart`
- **Upload state**: `UploadProvider` managing `List<UploadTask>` with status/progress/retry
- **File list state**: `fileListProvider` managing `List<EngramFile>` with search/filter/pagination

### API Contracts

No new API contracts. All refactoring is internal to the Flutter app.

### Quickstart Guide

See [quickstart.md](./quickstart.md) for validation scenarios.
