# Tasks: Client-Side Routing & Auth Flow Restructure

**Input**: Design documents from `/specs/006-client-routing/`

**Prerequisites**: [plan.md](./plan.md) (required), [spec.md](./spec.md) (required for user stories)

**Tests**: No test tasks mandated by spec. Verification is via `flutter analyze` and manual smoke test.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Root Flutter app**: `app/lib/`, `app/test/`
- **Docs/spec artifacts**: `specs/[###-feature-name]/`
- Use exact paths from plan.md.

---

## Phase 1: Setup (Shared Infrastructure)

No shared infrastructure setup needed. This feature is purely structural refactoring of existing Flutter routing code.

---

## Phase 2: Foundational (Blocking Prerequisites)

No blocking prerequisites. Tasks are organized by user story.

---

## Phase 3: User Story 1 — Deep-link to any page (Priority: P1) 🎯 MVP

**Goal**: Manual URL entry in the browser address bar navigates to the correct page after auth resolves, without flashing `/loading`.

**Independent Test**: Open a fresh browser, type `http://localhost:3000/settings`, press Enter. After auth resolves, land on the Settings screen. The URL never shows `/loading`.

### Implementation for User Story 1

- [X] T001 [US1] Strip `isLoading` redirect and add `callback`/`login` post-auth redirect in `app/lib/router/app_router.dart` — change the redirect function to return `null` when `authState.isLoading`; add `if (authState.isLoggedIn && path == '/callback') return '/vault'` and `if (authState.isLoggedIn && path == '/login') return '/vault'` after the loading check
- [X] T002 [P] [US1] Add loading overlay via `MaterialApp.router.builder` in `app/lib/main.dart` — wrap the child in a `Stack` with a `Consumer` that shows `CircularProgressIndicator` when `ref.watch(appAuthProvider.select((s) => s.isLoading))` is true
- [X] T003 [US1] Remove `/loading` route, `_pendingRedirect`, `_loadingTarget()`, `refreshListenable`, `_AuthRefreshNotifier`, `_authRefreshProvider`, and `_lastAuthState` from `app/lib/router/app_router.dart` — the redirect now reads auth state via `ref.read(appAuthProvider)` instead of the stale `_auth()` closure

**Checkpoint**: Typing any valid path (`/settings`, `/status`, `/upload`, `/vault`) in the address bar lands on the correct page. The URL never transitions through `/loading`. `flutter analyze` passes.

---

## Phase 4: User Story 2 — OIDC callback without JS hack (Priority: P1)

**Goal**: The OIDC redirect (`/callback?code=...&state=...`) is handled entirely in Dart without the pre-load `<script>` in `index.html`.

**Independent Test**: Perform an OIDC login flow end-to-end. The callback URL is processed by Dart, tokens are stored, user lands on `/vault`. No errors.

### Implementation for User Story 2

- [X] T004 [P] [US2] Remove the pre-load `<script>` block (lines 14–27) from `app/web/index.html` that intercepts OIDC callback params — the `Uri.base` fallback in `_oidcCallbackParams()` (`app/lib/auth_service_web.dart:109–121`) is the primary path now

**Checkpoint**: OIDC login flow completes without the JS hack. `flutter analyze` passes.

---

## Phase 5: User Story 3 — Clean redirect flow (Priority: P2)

**Goal**: The router's redirect function has a single responsibility (auth gating), with no residual dead code or workarounds for the old loading-splash approach.

**Independent Test**: `flutter analyze` passes. No functional change visible to the user.

### Implementation for User Story 3

- [X] T005 [US3] Verify no remaining references to `_pendingRedirect`, `/loading`, `_loadingTarget`, `_AuthRefreshNotifier`, or `_authRefreshProvider` in `app/lib/router/app_router.dart` — all dead code should have been removed in T003

**Checkpoint**: No dead code remains. `flutter analyze` passes.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification that the feature works end-to-end.

- [X] T006 Run `cd app && flutter analyze` — must report zero errors
- [ ] T007 Manual smoke test: deep-link entry (`/settings`, `/status`, `/upload`, `/vault`) on web, verify correct landing page after auth
- [ ] T008 Manual smoke test: OIDC login flow end-to-end, verify callback processing and redirect to `/vault`
- [ ] T009 Confirm no runtime state, secrets, or `.data/` content are included in the final diff

---

## Dependencies & Execution Order

### Phase Dependencies

- **US1 (Phase 3)**: No dependencies — can start immediately
- **US2 (Phase 4)**: Depends on US1 — the `Uri.base` fix depends on the URL not being overwritten by the loading redirect
- **US3 (Phase 5)**: Depends on US1 — cleanup of code removed during US1
- **Polish (Phase 6)**: Depends on US1 and US2

### Within Each User Story

- Changes within a single file (app_router.dart) must be done sequentially (T001 → T003)
- Parallel tasks (T002) are marked with [P] — different file from T001/T003

### Parallel Opportunities

- T001 and T002 can run in parallel (different files: app_router.dart vs main.dart)
- T003 must follow T001 (same file, dependent edits)
- T004 can run in parallel with T005 (different files)

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 3: User Story 1 (deep-link fix)
2. **STOP and VALIDATE**: Manual deep-link test
3. Deploy/demo if ready

### Incremental Delivery

1. Add US1 → Test manually → MVP ready
2. Add US2 → Test OIDC flow → Remove JS hack
3. Add US3 → Verify clean code

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify `flutter analyze` passes after each task
