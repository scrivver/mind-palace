# Tasks: Backend Display Paths

**Input**: Design documents from `/specs/008-backend-display-paths/`

**Prerequisites**: [plan.md](./plan.md), [spec.md](./spec.md), [research.md](./research.md), [data-model.md](./data-model.md), [contracts/file-display-path-contract.md](./contracts/file-display-path-contract.md), [quickstart.md](./quickstart.md)

**Tests**: Required. This is a cross-component contract fix, so focused tests must be written before implementation where practical.

**Organization**: Tasks are grouped by user story. Reliquary is the canonical event producer; Engram is the event consumer and metadata API owner.

## Phase 1: Setup

**Purpose**: Confirm backend source, tests, and contract files before editing submodules.

- [X] T001 Verify Reliquary event/upload source paths in `reliquary/backend/handler/handler.go`, `reliquary/backend/handler/handler_test.go`, `reliquary/backend/event/event.go`, and `reliquary/backend/event/event_test.go`
- [X] T002 Verify Engram ingestion/API source paths in `engram/ingestion/worker/handler.py`, `engram/ingestion/worker/db.py`, `engram/ingestion/tests/test_handler.py`, `engram/backend/internal/model/file.go`, and `engram/backend/internal/api/files.go`
- [X] T003 Verify file-event contract fixture paths in `reliquary/contracts/file-events/create.json`, `reliquary/contracts/file-events/README.md`, `engram/contracts/file-events/create.json`, and `engram/contracts/file-events/README.md`

---

## Phase 2: Foundational

**Purpose**: Shared contract understanding and test scaffolding that blocks story work.

**CRITICAL**: Complete this phase before user story implementation.

- [X] T004 [P] Add or update Reliquary file-event contract expectation for `filename=docs/myfile.pdf` and storage `file_path` in `reliquary/backend/event/event_test.go`
- [X] T005 [P] Add or update Engram ingestion fixture expectation for `filename=docs/myfile.pdf` in `engram/ingestion/tests/test_handler.py`
- [X] T006 [P] Add or update contract fixture examples for display path semantics in `reliquary/contracts/file-events/create.json` and `engram/contracts/file-events/create.json`
- [X] T007 Document the display path vs storage identity distinction in `reliquary/contracts/file-events/README.md` and `engram/contracts/file-events/README.md`

**Checkpoint**: Contract tests and fixtures describe the intended semantics before implementation.

---

## Phase 3: User Story 1 - Preserve Folder Upload Display Paths (Priority: P1) MVP

**Goal**: Reliquary emits the sanitized relative upload path as `filename` for folder uploads while keeping `file_path` as the storage key.

**Independent Test**: Simulate a multipart upload with form field `path=docs/myfile.pdf`; assert emitted create event has `filename=docs/myfile.pdf` and `file_path=files/<user>/<yyyy>/<mm>/docs/myfile.pdf`.

### Tests for User Story 1

- [X] T008 [P] [US1] Add failing Reliquary upload handler test for folder upload emitted filename in `reliquary/backend/handler/handler_test.go`
- [X] T009 [P] [US1] Add failing Reliquary upload handler test for normal basename upload compatibility in `reliquary/backend/handler/handler_test.go`
- [X] T010 [P] [US1] Add failing Reliquary sanitization test for unsafe relative path segments in `reliquary/backend/handler/handler_test.go`

### Implementation for User Story 1

- [X] T011 [US1] Change Reliquary upload flow to pass sanitized `storedName` or display path into create-event emission in `reliquary/backend/handler/handler.go`
- [X] T012 [US1] Change Reliquary `emitCreate` signature and event construction to set `Filename` from the display path argument in `reliquary/backend/handler/handler.go`
- [X] T013 [US1] Preserve delete event identity behavior without depending on display path changes in `reliquary/backend/handler/handler.go`
- [X] T014 [US1] Run Reliquary focused tests with `cd reliquary/backend && go test ./handler ./event`

**Checkpoint**: Reliquary emits correct display paths for new folder uploads.

---

## Phase 4: User Story 2 - Persist And Return Display Paths From Engram (Priority: P2)

**Goal**: Engram persists event `filename` as display path and returns it unchanged through list/detail APIs.

**Independent Test**: Ingest a create event with `filename=docs/myfile.pdf`; assert db upsert receives that filename and API list/detail JSON returns it.

### Tests for User Story 2

- [X] T015 [P] [US2] Add failing Engram ingestion test asserting `db.upsert_file` receives `filename=docs/myfile.pdf` in `engram/ingestion/tests/test_handler.py`
- [X] T016 [P] [US2] Add failing Engram db/upsert test or fixture coverage for updating `files.filename` on duplicate `(storage_type, file_path)` in `engram/ingestion/tests/`
- [X] T017 [P] [US2] Add failing Engram backend API test for `GET /api/files` returning `filename=docs/myfile.pdf` with unchanged `file_path` in `engram/backend/internal/api/files_test.go`
- [X] T018 [P] [US2] Add failing Engram backend API test for `GET /api/files/{id}` returning `filename=docs/myfile.pdf` with unchanged `file_path` in `engram/backend/internal/api/files_test.go`

### Implementation for User Story 2

- [X] T019 [US2] Verify Engram ingestion parser preserves event `filename` verbatim instead of deriving from `file_path` in `engram/ingestion/worker/handler.py`
- [X] T020 [US2] Verify Engram db upsert continues updating `files.filename = EXCLUDED.filename` for duplicate storage identity in `engram/ingestion/worker/db.py`
- [X] T021 [US2] Verify Engram API list/detail scan and JSON model expose persisted `filename` unchanged in `engram/backend/internal/api/files.go` and `engram/backend/internal/model/file.go`
- [X] T022 [US2] Run Engram focused tests with `cd engram && python -m unittest ingestion.tests.test_handler` and `cd engram/backend && go test ./internal/api`

**Checkpoint**: Engram stores and returns display paths without using `file_path` as UI input.

---

## Phase 5: User Story 3 - Document The Display Path Contract (Priority: P3)

**Goal**: Developers can clearly see that `filename` is the display path and `file_path` is storage identity.

**Independent Test**: Contract docs and examples show `filename=docs/myfile.pdf` and `file_path=files/alice/.../docs/myfile.pdf`.

### Tests for User Story 3

- [X] T023 [P] [US3] Add contract fixture validation or static check for display-path examples in `reliquary/backend/event/event_test.go`
- [X] T024 [P] [US3] Add contract fixture validation or static check for display-path examples in `engram/ingestion/tests/test_handler.py`

### Implementation for User Story 3

- [X] T025 [US3] Update Reliquary contract docs to define `filename` as sanitized relative display path in `reliquary/contracts/file-events/README.md`
- [X] T026 [US3] Update Engram contract docs to define `filename` as display path and `file_path` as storage identity in `engram/contracts/file-events/README.md`
- [X] T027 [US3] Update Spec Kit backend contract notes after implementation in `specs/008-backend-display-paths/contracts/file-display-path-contract.md`
- [X] T028 [US3] Run contract-related focused tests with `cd reliquary/backend && go test ./event` and `cd engram && python -m unittest ingestion.tests.test_handler`

**Checkpoint**: Contract documentation and examples match implemented behavior.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Formatting, full verification, submodule hygiene, and implementation notes.

- [X] T029 Run Go formatting for changed Reliquary and Engram Go files with `gofmt -w reliquary/backend/handler/handler.go reliquary/backend/handler/handler_test.go reliquary/backend/event/event_test.go engram/backend/internal/api/files_test.go`
- [X] T030 Run Python formatting/checks for changed Engram ingestion files using the repository's configured tooling or document why unavailable in `specs/008-backend-display-paths/quickstart.md`
- [X] T031 Run Reliquary backend tests with `cd reliquary/backend && go test ./...`
- [X] T032 Run Engram backend tests with `cd engram/backend && go test ./...`
- [X] T033 Run Engram ingestion validation with `cd engram && bin/test-ingest` or document why local infrastructure was unavailable in `specs/008-backend-display-paths/quickstart.md`
- [X] T034 Verify no `.data/` runtime state, secrets, generated tokens, local database files, or unrelated submodule changes are included in the final diff with `git status --short`
- [X] T035 Record final validation results in `specs/008-backend-display-paths/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup and blocks user stories.
- **US1 Reliquary event production (Phase 3)**: Depends on Foundational and is MVP.
- **US2 Engram persistence/API (Phase 4)**: Depends on Foundational; can proceed in parallel with US1 if using synthetic events, but end-to-end value requires US1.
- **US3 Contract docs (Phase 5)**: Depends on Foundational; should be finalized after US1 and US2 implementation details are confirmed.
- **Polish (Phase 6)**: Depends on all selected stories.

### User Story Dependencies

- **US1 (P1)**: MVP. Establishes correct producer behavior.
- **US2 (P2)**: Ensures consumer/API preserves producer display path.
- **US3 (P3)**: Documents the cross-component contract after implementation.

### Within Each User Story

- Write failing focused tests first where practical.
- Implement producer/consumer changes after tests.
- Run story-specific verification before marking story complete.
- Commit inside submodules first if committing later; root pointer update is separate.

---

## Parallel Opportunities

- T004, T005, and T006 can be prepared in parallel because they touch different test/fixture files.
- T008, T009, and T010 can be prepared in parallel if coordinated in `handler_test.go`.
- T015, T017, and T018 can be prepared in parallel because they cover ingestion and backend API separately.
- T025 and T026 can be updated in parallel because they touch separate submodules.

## Parallel Example: User Story 1

```bash
Task: "T008 [US1] Add failing Reliquary upload handler test for folder upload emitted filename in reliquary/backend/handler/handler_test.go"
Task: "T009 [US1] Add failing Reliquary upload handler test for normal basename upload compatibility in reliquary/backend/handler/handler_test.go"
Task: "T010 [US1] Add failing Reliquary sanitization test for unsafe relative path segments in reliquary/backend/handler/handler_test.go"
```

## Parallel Example: User Story 2

```bash
Task: "T015 [US2] Add failing Engram ingestion test asserting db.upsert_file receives filename=docs/myfile.pdf in engram/ingestion/tests/test_handler.py"
Task: "T017 [US2] Add failing Engram backend API test for GET /api/files returning filename=docs/myfile.pdf with unchanged file_path in engram/backend/internal/api/files_test.go"
Task: "T018 [US2] Add failing Engram backend API test for GET /api/files/{id} returning filename=docs/myfile.pdf with unchanged file_path in engram/backend/internal/api/files_test.go"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Setup and Foundational contract tests/fixtures.
2. Implement Reliquary event production fix.
3. Run `cd reliquary/backend && go test ./handler ./event`.
4. Validate emitted event shape before touching Engram.

### Incremental Delivery

1. Fix Reliquary event producer.
2. Verify Engram ingestion/API preserves and returns the event filename.
3. Update contract docs and fixtures.
4. Run component suites and record validation.

### Submodule Commit Strategy

If commits are requested later, commit Reliquary changes inside `reliquary/`, commit Engram changes inside `engram/`, then update the root repository submodule pointers separately.

## Notes

- Do not change storage key format.
- Do not change queue names or auth behavior.
- Do not backfill historical basename-only rows in this feature.
- Keep frontend fallback unchanged until backend-produced data is reliable.

---

## Phase 7: Convergence

**Purpose**: Close residual gaps found during post-implementation convergence review.

- [X] T036 Normalize backslash separators to forward slashes in `sanitizePath` before `path.Clean` in `reliquary/backend/handler/handler.go` per Edge Cases (missing)
- [X] T037 Add Reliquary handler test asserting backslash traversal paths (e.g. `..\..\evil.pdf`) are sanitized before becoming `filename` in `reliquary/backend/handler/handler_test.go` per Edge Cases (missing)
- [X] T038 Preserve folder-relative display path in the checksum-dedup branch of the Reliquary upload handler instead of falling back to a basename `filename`, or document dedup behavior as an accepted scope limit in the contract docs per Edge Cases (partial)
- [X] T039 Update the Engram rename path test/fixture to use a folder-style display path (e.g. `docs/myfile-final.pdf`) instead of a basename so SC-002 covers rename survival of display paths in `engram/ingestion/tests/test_handler.py` per SC-002 (partial)
