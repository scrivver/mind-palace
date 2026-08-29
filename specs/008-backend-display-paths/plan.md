# Implementation Plan: Backend Display Paths

**Branch**: `008-backend-display-paths` | **Date**: 2026-07-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/008-backend-display-paths/spec.md`

## Summary

Fix the backend display-path contract so Reliquary emits user-facing relative upload paths in `FileEvent.filename`, Engram persists that value, and Engram APIs return it as `filename`. This removes the need for the gallery to infer user directories from storage `file_path` for newly ingested folder uploads.

## Technical Context

**Language/Version**: Go 1.x in Reliquary and Engram backend; Python 3.13 in Engram ingestion worker.

**Primary Dependencies**: Existing stdlib Go HTTP/event code, existing Python ingestion/db modules. No new dependencies.

**Storage**: Existing object storage keys remain unchanged. Existing Engram PostgreSQL `files.filename` and `files.file_path` columns are reused.

**Testing**: Reliquary backend Go tests; Engram ingestion Python tests; Engram backend Go API tests where focused fixtures exist. Suggested commands: `cd reliquary/backend && go test ./...`, `cd engram && bin/test-ingest` or focused ingestion tests, and `cd engram/backend && go test ./...`.

**Target Platform**: Backend services used by local and deployed Mind Palace stacks.

**Project Type**: Cross-component backend contract fix in a Nix-managed monorepo with Git submodules.

**Performance Goals**: No additional network calls or storage reads. Event creation and ingestion remain O(1) for filename handling.

**Constraints**: Preserve storage identity `(storage_type, file_path)`. Do not change queue names, storage key format, auth, or frontend route behavior. Existing rows are not automatically backfilled unless explicitly added later.

**Scale/Scope**: Reliquary upload event emission, Engram ingestion persistence tests, Engram API response contract tests, and contract docs/fixtures.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: Use the root `nix develop` environment and component commands from Reliquary/Engram docs. Verification commands are listed in quickstart.
- **Component boundaries**: This feature intentionally spans `reliquary/` and `engram/`. `reliquary/README.md`, `reliquary/CLAUDE.md`, `engram/README.md`, and `engram/CLAUDE.md` were read before task generation.
- **Contract-driven integration**: The canonical file-event contract is affected semantically: `filename` means display path, `file_path` means storage identity. No queue, schema, or storage key changes.
- **Verification proportional to change**: Focused Reliquary event tests, Engram ingestion tests, Engram API tests, plus relevant component suites where feasible.
- **State and secret hygiene**: No new runtime state, migrations, secrets, or environment variables. `.data/` remains runtime-only and uncommitted.

Initial gate result: PASS.

## Project Structure

### Documentation (this feature)

```text
specs/008-backend-display-paths/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── file-display-path-contract.md
└── tasks.md
```

### Source Code (repository root)

```text
reliquary/
  backend/
    handler/handler.go
    handler/handler_test.go
    event/event.go
    event/event_test.go
  contracts/file-events/
    README.md
    create.json

engram/
  ingestion/
    worker/handler.py
    worker/db.py
    tests/test_handler.py
  backend/
    internal/model/file.go
    internal/api/files.go
    internal/api/*_test.go
  contracts/file-events/
    README.md
    create.json
```

**Structure Decision**: Keep the display path in the existing `filename` field across event, ingestion, database, and API boundaries. Keep `file_path` unchanged as storage identity.

## Phase 0: Research

See [research.md](./research.md).

## Phase 1: Design

See [data-model.md](./data-model.md), [contracts/file-display-path-contract.md](./contracts/file-display-path-contract.md), and [quickstart.md](./quickstart.md).

## Post-Design Constitution Check

- **Nix-first reproducibility**: Verification remains component-command based from root Nix environment.
- **Component boundaries**: Design names Reliquary as event producer and Engram as event consumer/API owner.
- **Contract-driven integration**: Contract artifact captures exact event/API semantics and idempotency behavior.
- **Verification proportional to change**: Task list must include focused tests before implementation for Reliquary events and Engram ingestion/API.
- **State and secret hygiene**: No migration or secret impact.

Post-design gate result: PASS.

## Complexity Tracking

No constitution violations.
