# Feature Specification: Frontend Codebase Refactoring

**Feature Directory**: `specs/004-frontend-refactoring`

**Created**: 2026-06-23

**Status**: Draft

**Input**: User request: "I think the mind palace frontend source code is getting too large, it is time to do some refactoring."

## Problem Statement

The Flutter frontend at `app/lib/` has grown organically to 34 source files (plus platform variants) without a formal state management library, centralized DI, or navigation system. Key metrics:

| File | Lines | Issue |
|------|-------|-------|
| `main.dart` | 353 | God class (`HomePage`): auth gate, service creation, navigation, theme stream — all in one widget |
| `gallery_screen.dart` | 1097 | Contains 4 private widget classes; filter state, data loading, pagination, and layout all in one file |
| `upload_screen.dart` | 734 | Drop logic, file picking, upload orchestration, progress tracking, plus 3 private classes |
| `file_detail_screen.dart` | 685 | Preview logic, multiple actions, responsive layout, extracted text dialog |

Duplicated code fragments (`_iconForMime`, `formattedSize`, `_relativeTime`, auth config probing) appear in 2-4 locations each. No centralized error handling. Only 2 test files.

## User Scenarios & Testing

### User Story 1 - Maintainability (Priority: P1)

As a developer, I want the codebase split into focused files with clear responsibilities so that adding new features or fixing bugs requires understanding only the relevant module.

**Independent Test**: After refactoring, `flutter analyze` passes with zero errors. The app builds and runs without regression on the known navigation paths (login → gallery → file detail → upload → settings).

**Acceptance Scenarios**:
1. **Given** the refactored codebase, **When** `flutter analyze` is run, **Then** no errors or warnings are emitted.
2. **Given** the refactored codebase, **When** the app starts and a user logs in, **Then** the gallery screen loads and displays files as before.
3. **Given** the refactored codebase, **When** a developer navigates to any screen, **Then** all screens render without widget-tree errors.

### User Story 2 - Extensibility (Priority: P1)

As a developer, I want a DI container (Provider or Riverpod) replacing manual service wiring in `HomePage` so that new services or screens can be added without modifying the god class.

**Independent Test**: The app still starts, authenticates, and navigates correctly after migrating from `main.dart`-based DI to the chosen solution.

**Acceptance Scenarios**:
1. **Given** the refactored DI setup, **When** the app initializes, **Then** all services (`AuthService`, `ReliquaryService`, `EngramService`, `ThemeService`) are available without `main.dart` creating them inline.
2. **Given** a new screen is added, **When** it needs `EngramService`, **Then** the developer obtains it via the DI container without modifying `HomePage`.

### User Story 3 - Eliminate Duplication (Priority: P2)

As a developer, I want duplicated utility code consolidated into shared modules so that fixing a formatting or icon bug fixes it everywhere at once.

**Independent Test**: After consolidation, `grep -rn` for the extracted functions shows exactly one definition per function.

**Acceptance Scenarios**:
1. **Given** duplicated `_iconForMime` functions in gallery and file detail screens, **When** refactored, **Then** a single shared `extension` or `static method` is used by both.
2. **Given** duplicated `formattedSize` in models and screens, **When** refactored, **Then** a single utility lives in `app/lib/utils/format.dart`.

## Requirements

### Functional Requirements (User-Facing — No Change)

- **FR-000**: All existing user-facing behavior MUST be preserved. No visual or behavioral changes.
- **FR-001**: The app MUST survive the refactoring with zero regression on all screens.

### Non-Functional / Engineering Requirements

- **ER-001**: A DI container (Riverpod or Provider) MUST replace manual service wiring from `main.dart`.
- **ER-002**: Navigation MUST use a standard Flutter routing solution (`go_router` or `Navigator 2.0`) instead of index-based `_navIndex` in `HomePage`.
- **ER-003**: `gallery_screen.dart` MUST be split: extract `_QuickFilterChip`, `_FileTile`, `_FilterDropdownPanel` into separate files under `widgets/gallery/`.
- **ER-004**: `upload_screen.dart` MUST be split: extract `_DashedBorderPainter`, `_UploadFileTile`, `_UploadProgress` into separate files. Consider creating `UploadService` for queue management.
- **ER-005**: `file_detail_screen.dart` MUST be split: extract preview sections (PDF, image), `_DeleteDialog`, and extracted text dialog into separate files.
- **ER-006**: Duplicated utility code (`_iconForMime`, `formattedSize`, `_relativeTime`) MUST be consolidated into shared extension methods or standalone utils in `app/lib/utils/`.
- **ER-007**: Auth config probing (currently in 3 places) MUST be consolidated into a single method on `server_url_store.dart` or a dedicated `ServerService`.
- **ER-008**: Error handling MUST use a centralized approach (e.g., logger service) rather than scattered `ScaffoldMessenger` and `debugPrint` calls.
- **ER-009**: The `refreshTrigger` int-key pattern MUST be replaced by a reactive invalidation mechanism (e.g., Riverpod `ref.invalidate()` or a `ValueNotifier`).
- **ER-010**: All refactored code MUST pass `flutter analyze` with zero errors.
- **ER-011**: Tests MUST be added or updated for refactored modules to maintain or improve existing test coverage.

### Key Entities

- **ServiceContainer**: The DI abstraction (Provider/Riverpod) that makes services available to all widgets without manual wiring.
- **AppRouter**: The routing abstraction (go_router) that replaces `_navIndex`-based navigation.
- **SharedUtils**: Consolidated utility functions for `iconForMime`, `formatBytes`, `relativeTime`.
- **ScreenWidgets**: Extracted private widgets from large screens into dedicated files.
- **LoggerService**: Centralized error/logging abstraction.

### Contracts & Integration Impact

- **Affected Components**: `app/` only. No changes to `reliquary/`, `engram/`, `synapse/`, or `infra/`.
- **Contracts**: No new API endpoints or event contracts. All refactoring is pure code reorganization within the Flutter app.
- **State & Migrations**: Theme preference storage mechanism unchanged. No database migrations.
- **Secrets/Configuration**: No new secrets or environment variables.
- **Risk**: High touch surface — all screens and services will be touched. Requires careful incremental approach and verification at each step.

## Success Criteria

- **SC-001**: `flutter analyze` reports zero errors after all refactoring steps.
- **SC-002**: `flutter test` passes all existing tests (augmented for refactored modules).
- **SC-003**: All screens render and function identically to pre-refactoring: login, gallery, file detail, upload, settings, status.
- **SC-004**: `main.dart` shrinks by at least 40% — service instantiation and routing are no longer inline in `HomePage`.
- **SC-005**: No duplicated utility function remains — each utility lives in exactly one file.

## Assumptions

- The existing architecture (service-based, `setState`) can be incrementally refactored without a full rewrite.
- Riverpod is available and compatible with the existing Flutter/Dart version.
- `go_router` supports the existing navigation patterns (sidebar-driven screen switching).
- Team is comfortable with Dart extension methods and utility functions.
- Conditional import platform abstraction pattern (used for web/native separation) should be preserved.
