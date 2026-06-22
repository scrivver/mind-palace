---

description: "Task list for Sanctuary Health Status Page feature"
---

# Tasks: Sanctuary Health Status Page

**Input**: Design documents from `specs/002-sanctuary-health/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/engram-stats-api.md, contracts/engram-activity-api.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Root Flutter app**: `app/lib/`, `app/test/`
- **Engram submodule**: `engram/backend/` Go API paths
- Use exact paths from plan.md

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Verify environment and establish branch

- [ ] T001 Create and switch to `002-sanctuary-health` feature branch from a clean `main`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Go response models and route registration that ALL user stories depend on

- [x] T002 Define Go `StatsResponse` and `ActivityResponse` model types in `engram/backend/internal/model/stats.go`
- [x] T003 [P] Register `GET /api/stats` and `GET /api/activity` routes in `engram/backend/internal/api/router.go`

**Checkpoint**: Foundation ready — all user stories can now begin

---

## Phase 3: User Story 1 — View System Health Dashboard (Priority: P1) 🎯 MVP

**Goal**: Display Engram Engine card, system metric tiles (Latency, Sync Speed, Uptime), and Storage Capacity section on the Status page.

**Independent Test**: Navigate to Status page via sidebar and verify all health metric cards display meaningful data without error states.

### Implementation for User Story 1

- [x] T004 [P] [US1] Implement `GET /api/stats` handler with DB queries in `engram/backend/internal/api/stats.go`
- [x] T005 [P] [US1] Extend `EngramService` with `getStats()` in `app/lib/engram_service.dart`
- [x] T006 [US1] Create `StatusScreen` StatefulWidget with engine card, three metric tiles, and storage capacity section in `app/lib/screens/status_screen.dart`
- [x] T007 [US1] Wire `StatusScreen` into `app/lib/main.dart` with bottom navigation replacing direct GalleryScreen return

**Checkpoint**: US1 complete — Status page shows engine metrics, latency/sync/uptime tiles, and storage breakdown

---

## Phase 4: User Story 2 — View Recent Activity Feed (Priority: P2)

**Goal**: Display a timeline of recent file state transitions with icons, descriptions, and relative timestamps.

**Independent Test**: Verify recent activity entries appear with icon, description text, and relative timestamps when the Status page loads.

### Implementation for User Story 2

- [x] T008 [P] [US2] Implement `GET /api/activity` handler with DB query and icon mapping in `engram/backend/internal/api/activity.go`
- [x] T009 [P] [US2] Extend `EngramService` with `getActivity(limit, offset)` in `app/lib/engram_service.dart`
- [x] T010 [US2] Add Recent Activity section with timeline entries and "View Archive" link to `StatusScreen` in `app/lib/screens/status_screen.dart`

**Checkpoint**: US2 complete — activity feed renders with icons, descriptions, relative timestamps, and View Archive link

---

## Phase 5: User Story 3 — Handle Service Degradation (Priority: P3)

**Goal**: Show loading indicators, per-section error/degraded states, and pull-to-refresh so the user never sees a broken or empty page.

**Independent Test**: Simulate a backend failure (stop Engram) and verify affected sections show degraded state rather than crashing.

### Implementation for User Story 3

- [x] T011 [US3] Add loading indicator (shimmer/skeleton) to each Status section in `app/lib/screens/status_screen.dart`
- [x] T012 [US3] Add per-section error handling: degraded state for Engram card when `/api/stats` fails, fallback display when Reliquary stats fail, and error message when activity feed fails in `app/lib/screens/status_screen.dart`
- [x] T013 [US3] Add pull-to-refresh via `RefreshIndicator` to `StatusScreen` in `app/lib/screens/status_screen.dart`

**Checkpoint**: US3 complete — page degrades gracefully per section and recovers on refresh

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification, cleanup, and documentation

- [x] T014 [P] Run `cd app && flutter analyze` — fix any static analysis issues
- [x] T015 [P] Run `cd engram && go test ./...` — ensure existing Go tests still pass
- [ ] T016 Run full E2E validation per `specs/002-sanctuary-health/quickstart.md` scenarios (requires running stack)
- [x] T017 Verify no runtime state, secrets, local database files, or `.data/` content are included in the diff

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — can start after foundational
- **US2 (Phase 4)**: Depends on Phase 3 (StatusScreen exists) — adds activity section to existing screen
- **US3 (Phase 5)**: Depends on Phase 3 (StatusScreen exists) — enhances existing screen with error handling
- **Polish (Phase 6)**: Depends on Phases 3-5 — verification suite

### User Story Dependencies

- **US1 (P1)**: Independent — can start after foundational
- **US2 (P2)**: Depends on US1 (needs StatusScreen widget to exist)
- **US3 (P3)**: Depends on US1 (needs StatusScreen widget to exist)

### Within Each Phase

- [P] tasks within a phase can run in parallel
- Non-[P] tasks run sequentially (dependencies within the phase)

---

## Parallel Execution Examples

### Foundational Phase (Phase 2)

```bash
# T002 and T003 are independent
Task: "Define Go models in engram/backend/internal/model/stats.go"
Task: "Register routes in engram/backend/internal/api/router.go"
```

### User Story 1

```bash
# T004 and T005 are independent (Go handler vs Dart service)
Task: "Implement GET /api/stats handler in engram/backend/internal/api/stats.go"
Task: "Extend EngramService with getStats() in app/lib/services/engram_service.dart"

# T006 depends on T005, T007 depends on T006
Task: "Create StatusScreen widget in app/lib/screens/status_screen.dart"
Task: "Wire into main.dart"
```

### User Story 2

```bash
# T008 and T009 are independent
Task: "Implement GET /api/activity handler in engram/backend/internal/api/activity.go"
Task: "Extend EngramService with getActivity() in app/lib/services/engram_service.dart"

# T010 depends on T009
Task: "Add Activity section to StatusScreen"
```

### Polish Phase

```bash
# T014 and T015 are independent
Task: "Run flutter analyze"
Task: "Run go test ./..."
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branch creation)
2. Complete Phase 2: Foundational (Go models + routes)
3. Complete Phase 3: User Story 1 (engine card, metrics, storage + navigation)
4. **STOP and VALIDATE**: Test US1 independently — navigate to Status page, verify cards render
5. Demo-ready with core dashboard

### Incremental Delivery

1. Complete Phases 1–2 → Foundation ready
2. Add US1 → Test independently → **MVP!**
3. Add US2 → Test independently → Activity feed added
4. Add US3 → Test independently → Error handling complete
5. Polish → Verification suite passes

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- Commit after phase-major checkpoints
- MVP scope = Phases 1 + 2 + 3 only (US1 — dashboard with engine, metrics, storage)
