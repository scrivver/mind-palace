# Tasks: Dogfood Deployment

**Input**: Design documents from `/specs/001-dogfood-deployment/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Include focused validation tasks before implementation where practical because this feature changes orchestration, deployment contracts, and dogfood smoke paths.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Root orchestration**: `flake.nix`, `shells/`, `infra/`, `bin/`
- **Root deployment docs/config**: `docker-compose.yml`, `.env.example`, `docs/dogfood-deployment.md`
- **Spec artifacts**: `specs/001-dogfood-deployment/`
- **Submodules**: `reliquary/`, `engram/`, `synapse/` only when component-owned packaged entrypoints or health checks are needed

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the implementation baseline, ignore coverage, and target file ownership before changing runtime behavior.

- [X] T001 Inspect current root orchestration files and record existing dev/infra behavior in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T002 Inspect Reliquary deployment pattern and record reusable build/compose conventions in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T003 [P] Verify root `.gitignore` covers `.data/`, `.env`, generated container outputs, and local logs in `.gitignore`
- [X] T004 [P] Create root `.dockerignore` with Nix, Docker, Flutter, Go, Python, `.data/`, `.git/`, `.env*`, and build-output exclusions in `.dockerignore`
- [X] T005 [P] Identify required component-owned image or healthcheck gaps for `reliquary/`, `engram/`, and `synapse/` in `specs/001-dogfood-deployment/implementation-notes.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define shared service contracts, container targets, and documentation scaffolding that all user stories depend on.

**CRITICAL**: No user story work can begin until this phase is complete.

- [X] T006 Add root full-stack process-compose service definitions for Reliquary, Engram, Synapse, and the primary app in `flake.nix`
- [X] T007 Update root process-compose generation to produce both infra-only and full-stack configs in `flake.nix`
- [X] T008 Update shell setup to copy both generated process-compose configs and export socket/config paths in `shells/infra.nix`
- [X] T009 Update root dev shell environment variables for service URLs, state paths, and local dogfood defaults in `shells/dev.nix`
- [X] T010 Add packaged container package targets for root deployment images in `flake.nix`
- [X] T011 [P] Add root deployment documentation skeleton with local and packaged sections in `docs/dogfood-deployment.md`
- [X] T012 [P] Add root packaged environment placeholder file in `.env.example`

**Checkpoint**: Shared orchestration and deployment scaffolding is ready for story implementation.

---

## Phase 3: User Story 1 - Start Local Dogfood Environment (Priority: P1) MVP

**Goal**: A developer can start the complete local dogfood stack with one root `dev` command after entering `nix develop`.

**Independent Test**: From the root dev shell, `dev` starts shared infrastructure, backends, workers, proxy/identity, and the primary app without a separate `start-infra`; status/logs are visible through process-compose and shutdown preserves `.data/`.

### Tests for User Story 1

- [X] T013 [US1] Add a local dev contract validation script for generated full-stack process names and dependency coverage in `specs/001-dogfood-deployment/validation/local-dev-contract.sh`
- [X] T014 [US1] Run the local dev contract validation and record expected pre-implementation failures in `specs/001-dogfood-deployment/implementation-notes.md`

### Implementation for User Story 1

- [X] T015 [US1] Replace tmux-based root full-stack startup with process-compose full-stack startup in `bin/dev`
- [X] T016 [US1] Update root infra-only startup to explicitly use the infra-only generated config in `bin/start-infra`
- [X] T017 [US1] Update root shutdown behavior to stop the active process-compose stack without deleting `.data/` in `bin/shutdown-infra`
- [X] T018 [US1] Update root environment loading for Reliquary, Engram, Synapse, Authentik, Caddy, RabbitMQ, MinIO, and PostgreSQL values in `bin/load-infra-env`
- [X] T019 [US1] Update primary app startup to work under process-compose-managed environment values in `bin/start-app`
- [X] T020 [US1] Document local dogfood startup, status, logs, shutdown, and reset behavior in `docs/dogfood-deployment.md`
- [X] T021 [US1] Update root development command guidance to make `dev` the default one-command startup path in `AGENTS.md`
- [X] T022 [US1] Run local dev contract validation and mark US1 validation results in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - Run Packaged Dogfood Deployment (Priority: P2)

**Goal**: A maintainer can build/load root deployment images and run the packaged Mind Palace dogfood stack through a documented Compose workflow.

**Independent Test**: Follow `docs/dogfood-deployment.md` from image build/load through compose startup, status, logs, health, shutdown, and reset using `.env.example` placeholders replaced for local use.

### Tests for User Story 2

- [X] T023 [P] [US2] Add a packaged Compose contract validation script for required services, images, ports, volumes, and internal-only dependencies in `specs/001-dogfood-deployment/validation/packaged-compose-contract.sh`
- [X] T024 [P] [US2] Add an environment example validation script for required placeholders and secret warnings in `specs/001-dogfood-deployment/validation/env-example-contract.sh`
- [X] T025 [US2] Run packaged deployment contract validations and record expected pre-implementation failures in `specs/001-dogfood-deployment/implementation-notes.md`

### Implementation for User Story 2

- [X] T026 [US2] Add root split-service packaged deployment in `docker-compose.yml`
- [X] T027 [US2] Populate packaged environment variables, safe defaults, and required secret placeholders in `.env.example`
- [X] T028 [US2] Add root image build/load workflow for Docker or Podman in `bin/deploy`
- [X] T029 [US2] Add or wire Nix container definitions for root packaged images under `nix/`
- [X] T030 [US2] Add packaged ingress configuration and health behavior for the public entry point under `nix/`
- [X] T031 [US2] Add packaged deployment build, startup, status, log, shutdown, and reset docs in `docs/dogfood-deployment.md`
- [X] T032 [US2] Document image names, service boundaries, volumes, and internal service exposure rules in `docs/dogfood-deployment.md`
- [X] T033 [US2] Run packaged Compose and environment contract validations and record US2 validation results in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: User Story 2 is independently functional and testable.

---

## Phase 5: User Story 3 - Compare Development and Packaged Behavior (Priority: P3)

**Goal**: Dogfooding participants can run one parity smoke checklist against both deployment paths and report failures with consistent diagnostics.

**Independent Test**: Run the documented smoke checklist for both local-dev and packaged-compose paths, then confirm known differences and failure-report fields are documented.

### Tests for User Story 3

- [X] T034 [P] [US3] Add a documentation validation script for parity checklist, known differences, and failure report fields in `specs/001-dogfood-deployment/validation/dogfood-docs-contract.sh`
- [X] T035 [US3] Run documentation validation and record expected pre-implementation failures in `specs/001-dogfood-deployment/implementation-notes.md`

### Implementation for User Story 3

- [X] T036 [US3] Add shared local and packaged dogfood smoke checklist steps in `docs/dogfood-deployment.md`
- [X] T037 [US3] Add known-differences table for local-dev versus packaged-compose behavior in `docs/dogfood-deployment.md`
- [X] T038 [US3] Add failure report template covering deployment path, state freshness, status, logs, config source, and failed smoke step in `docs/dogfood-deployment.md`
- [X] T039 [US3] Update quickstart validation guidance to match final dogfood commands and smoke steps in `specs/001-dogfood-deployment/quickstart.md`
- [X] T040 [US3] Run dogfood documentation validation and record US3 validation results in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: All user stories are independently functional.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, formatting, and state/secret hygiene checks across the completed feature.

- [X] T041 [P] Run Nix formatting or manual formatting checks for `flake.nix`, `shells/infra.nix`, `shells/dev.nix`, and files under `nix/`
- [X] T042 [P] Run shell syntax checks for `bin/dev`, `bin/start-infra`, `bin/shutdown-infra`, `bin/load-infra-env`, `bin/start-app`, and `bin/deploy`
- [X] T043 [P] Run YAML validation for `docker-compose.yml`
- [X] T044 [P] Run repository whitespace validation with `git diff --check`
- [X] T045 Run local process-compose config evaluation with `nix develop` or an equivalent Nix eval command and record the result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T046 Run packaged image target evaluation or build command for root container outputs and record the result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T047 Run relevant component checks for touched areas and record skipped checks with reasons in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T048 Verify no generated runtime state, secrets, local database files, Compose volumes, or `.data/` content are included in the final diff
- [X] T049 Update task completion status in `specs/001-dogfood-deployment/tasks.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on Setup completion and blocks all user stories.
- **User Story 1 (Phase 3)**: Depends on Foundational. This is the MVP path.
- **User Story 2 (Phase 4)**: Depends on Foundational and can proceed independently of US1 except for shared docs coordination.
- **User Story 3 (Phase 5)**: Depends on US1 and US2 documentation and command names.
- **Polish (Phase 6)**: Depends on all desired user stories.

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational; no dependency on packaged deployment.
- **User Story 2 (P2)**: Can start after Foundational; no dependency on local `dev` implementation except shared docs names.
- **User Story 3 (P3)**: Requires both deployment paths to exist so parity and known differences are meaningful.

### Within Each User Story

- Validation scripts are written before implementation where practical.
- Contract validation is run before implementation to capture expected failures.
- Implementation updates command/config/docs files.
- Validation is rerun after implementation and results are recorded.

## Parallel Opportunities

- T003, T004, and T005 can run in parallel after T001 and T002.
- T011 and T012 can run in parallel after T006-T010 are understood.
- T023 and T024 can run in parallel for packaged deployment validation.
- T041, T042, T043, and T044 can run in parallel during polish.

## Parallel Example: User Story 2

```bash
Task: "T023 [P] [US2] Add a packaged Compose contract validation script for required services, images, ports, volumes, and internal-only dependencies in specs/001-dogfood-deployment/validation/packaged-compose-contract.sh"
Task: "T024 [P] [US2] Add an environment example validation script for required placeholders and secret warnings in specs/001-dogfood-deployment/validation/env-example-contract.sh"
```

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete User Story 1 tasks T013-T022.
3. Validate that `dev` starts the full local process-compose stack without a prior `start-infra`.
4. Stop and review before packaged deployment work.

### Incremental Delivery

1. Local dogfood startup via root process-compose.
2. Packaged Compose dogfood deployment.
3. Shared parity smoke checklist and failure report template.
4. Final formatting, validation, and state/secret hygiene checks.

### Notes

- Keep submodule changes inside the owning submodule and update root pointers only after submodule commits.
- Do not commit `.data/`, `.env`, generated process-compose YAML, local database files, container tarballs, or Compose volumes.
- Keep `start-infra` available for targeted debugging, but make `dev` the default dogfood command.
