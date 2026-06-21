# Tasks: Dogfood Deployment

**Input**: Design documents from `/specs/001-dogfood-deployment/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Include focused package evaluation, image build/load, compose config,
component checks, and quickstart validation tasks for changed behavior. If a
check cannot be run locally, record the reason in
`specs/001-dogfood-deployment/implementation-notes.md`.

**Organization**: Tasks are grouped by user story. This continuation focuses on
the packaged deployment path and the corrected ownership boundary: Engram and
Synapse own their package/image outputs; Mind Palace consumes those child-repo
outputs for the platform Compose deployment.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`US1`, `US2`, `US3`)
- Include exact file paths in descriptions

## Path Conventions

- **Root infrastructure/orchestration**: `flake.nix`, `bin/`, `shells/`, `infra/`
- **Root packaged deployment**: `docker-compose.yml`, `.env.example`, `.dockerignore`, `docs/`
- **Engram submodule**: `engram/`, including `engram/backend/`, `engram/ingestion/`, `engram/nix/`
- **Synapse submodule**: `synapse/`, including `synapse/cmd/`, `synapse/internal/`, `synapse/nix/`
- **Specs and validation**: `specs/001-dogfood-deployment/`

## Phase 1: Setup (Shared Context)

**Purpose**: Establish the current component contracts and deployment surface before editing code.

- [X] T001 Review Engram packaging-relevant guidance in `engram/README.md` and `engram/CLAUDE.md`
- [X] T002 Review Synapse packaging-relevant guidance in `synapse/README.md` and `synapse/CLAUDE.md`
- [X] T003 [P] Inspect Reliquary split-image precedent in `reliquary/nix/backend.nix`, `reliquary/nix/api-container.nix`, and `reliquary/nix/thumbnail-worker-container.nix`
- [X] T004 [P] Inspect Reliquary deploy precedent in `reliquary/bin/deploy` and record applicable image load/tag behavior in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T005 [P] Audit current root placeholder image outputs in `flake.nix` and list targets to remove or replace in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T006 [P] Audit current root packaged Compose image references in `docker-compose.yml` and list required child image mappings in `specs/001-dogfood-deployment/implementation-notes.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Define stable child-repo output contracts that root deployment can consume.

**CRITICAL**: No root packaged deployment wiring should be finalized until this phase is complete.

- [X] T007 Define Engram package/image output contract names in `engram/README.md`
- [X] T008 Define Synapse package/image output contract names in `synapse/README.md`
- [X] T009 [P] Add Engram packaging notes for API image environment, port, and healthcheck in `engram/README.md`
- [X] T010 [P] Add Engram packaging notes for ingestion image environment and runtime tools in `engram/README.md`
- [X] T011 [P] Add Synapse packaging notes for worker image environment and liveness expectations in `synapse/README.md`
- [X] T012 [P] Add Synapse packaging notes for reconciler image environment and Engram API dependency in `synapse/README.md`
- [X] T013 Create or update Engram Nix package directory structure in `engram/nix/`
- [X] T014 Create or update Synapse Nix package directory structure in `synapse/nix/`
- [X] T015 Update packaging ownership notes in `specs/001-dogfood-deployment/contracts/packaged-compose-deployment.md`
- [X] T016 Update packaged deployment validation expectations in `specs/001-dogfood-deployment/quickstart.md`

**Checkpoint**: Engram and Synapse output contracts are documented before implementation.

---

## Phase 3: User Story 1 - Start Local Dogfood Environment (Priority: P1)

**Goal**: Preserve the verified one-command local dogfood startup while packaged image work proceeds.

**Independent Test**: Enter `nix develop`, run `dev`, confirm the generated process-compose stack still starts local infrastructure, backends, workers, and app without a separate `start-infra` step.

### Implementation for User Story 1

- [X] T017 [US1] Confirm root dev shell still generates full-stack process-compose config in `shells/infra.nix`
- [X] T018 [US1] Confirm root `dev` still starts the generated full-stack process-compose config in `bin/dev`
- [X] T019 [US1] Confirm Engram local startup still waits for Authentik OIDC discovery in `flake.nix`
- [X] T020 [US1] Confirm RabbitMQ local readiness remains a lightweight AMQP TCP probe in `infra/rabbitmq.nix`
- [X] T021 [US1] Run local dev-shell evaluation and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T022 [US1] Run local process-compose YAML parse validation and record result in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: Local dogfood startup behavior remains intact.

---

## Phase 4: User Story 2 - Run Packaged Dogfood Deployment (Priority: P2)

**Goal**: Build and run a packaged Mind Palace deployment using real component-owned Engram and Synapse images consumed by root Compose.

**Independent Test**: Build Engram and Synapse image outputs from their child repos, run root `bin/deploy` to load/tag all images, run `docker compose config --quiet`, start the packaged deployment, and probe the public entrypoint plus Engram health route.

### Engram Package and Image Outputs

- [X] T023 [P] [US2] Add Engram Go backend package derivation in `engram/nix/backend.nix`
- [X] T024 [P] [US2] Add Engram API container image derivation in `engram/nix/api-container.nix`
- [X] T025 [P] [US2] Add Engram API container healthcheck helper in `engram/nix/api-container.nix`
- [X] T026 [P] [US2] Add Engram Python ingestion runtime derivation in `engram/nix/ingestion.nix`
- [X] T027 [P] [US2] Add Engram ingestion container image derivation in `engram/nix/ingestion-container.nix`
- [X] T028 [US2] Wire Engram package and image outputs into `engram/flake.nix`
- [X] T029 [US2] Ensure Engram API image exposes port and default environment contract in `engram/nix/api-container.nix`
- [X] T030 [US2] Ensure Engram ingestion image includes required extraction tools and CA certificates in `engram/nix/ingestion-container.nix`
- [X] T031 [US2] Add Engram image build documentation to `engram/README.md`
- [X] T032 [US2] Add Engram image output notes to `engram/CLAUDE.md`

### Synapse Package and Image Outputs

- [X] T033 [P] [US2] Add Synapse Go command package derivation in `synapse/nix/synapse.nix`
- [X] T034 [P] [US2] Add Synapse worker container image derivation in `synapse/nix/worker-container.nix`
- [X] T035 [P] [US2] Add Synapse reconciler container image derivation in `synapse/nix/reconciler-container.nix`
- [X] T036 [P] [US2] Add Synapse worker liveness helper in `synapse/nix/worker-container.nix`
- [X] T037 [P] [US2] Add Synapse reconciler liveness helper in `synapse/nix/reconciler-container.nix`
- [X] T038 [US2] Wire Synapse package and image outputs into `synapse/flake.nix`
- [X] T039 [US2] Ensure Synapse package includes worker, reconciler, and metagen binaries in `synapse/nix/synapse.nix`
- [X] T040 [US2] Add Synapse image build documentation to `synapse/README.md`
- [X] T041 [US2] Add Synapse image output notes to `synapse/CLAUDE.md`

### Root Platform Consumption

- [X] T042 [US2] Remove root placeholder Engram and Synapse container implementations from `flake.nix`
- [X] T043 [US2] Update root package outputs in `flake.nix` to keep only root-owned app and ingress artifacts or thin aliases
- [X] T044 [US2] Update root deploy target list to build Engram child outputs from `bin/deploy`
- [X] T045 [US2] Update root deploy target list to build Synapse child outputs from `bin/deploy`
- [X] T046 [US2] Add root image tagging from Engram child image names to `mind-palace-engram-*` names in `bin/deploy`
- [X] T047 [US2] Add root image tagging from Synapse child image names to `mind-palace-synapse-*` names in `bin/deploy`
- [X] T048 [US2] Update root deploy error messages for missing or renamed child flake outputs in `bin/deploy`
- [X] T049 [US2] Update packaged Compose dependencies for real Engram and Synapse services in `docker-compose.yml`
- [X] T050 [US2] Add or update packaged healthchecks for Engram and Synapse services in `docker-compose.yml`
- [X] T051 [US2] Ensure packaged Compose environment variables match child image contracts in `docker-compose.yml`
- [X] T052 [US2] Update packaged configuration placeholders for Engram and Synapse in `.env.example`

### Packaged Deployment Documentation and Validation

- [X] T053 [P] [US2] Update packaged build/load instructions for child-owned image outputs in `docs/dogfood-deployment.md`
- [X] T054 [P] [US2] Update packaged troubleshooting guidance for child build failures in `docs/dogfood-deployment.md`
- [X] T055 [P] [US2] Update packaged failure-report guidance for child packaging versus root orchestration failures in `docs/dogfood-deployment.md`
- [X] T056 [P] [US2] Update packaged compose contract validation script for child image ownership in `specs/001-dogfood-deployment/validation/packaged-compose-contract.sh`
- [X] T057 [P] [US2] Update docs validation script for child image build/load instructions in `specs/001-dogfood-deployment/validation/dogfood-docs-contract.sh`
- [X] T058 [US2] Add validation for Engram child output names to `specs/001-dogfood-deployment/validation/packaged-compose-contract.sh`
- [X] T059 [US2] Add validation for Synapse child output names to `specs/001-dogfood-deployment/validation/packaged-compose-contract.sh`
- [X] T060 [US2] Run `nix eval --json path:./engram#packages.x86_64-linux --apply 'builtins.attrNames'` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T061 [US2] Run `nix eval --json path:./synapse#packages.x86_64-linux --apply 'builtins.attrNames'` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T062 [US2] Build Engram API image with `nix build path:./engram#api-container --no-link --print-out-paths` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T063 [US2] Build Engram ingestion image with `nix build path:./engram#ingestion-container --no-link --print-out-paths` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T064 [US2] Build Synapse worker image with `nix build path:./synapse#worker-container --no-link --print-out-paths` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T065 [US2] Build Synapse reconciler image with `nix build path:./synapse#reconciler-container --no-link --print-out-paths` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T066 [US2] Run root `./bin/deploy` image build/load flow and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T067 [US2] Run `docker compose config --quiet` or equivalent Podman command and record result in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: Packaged deployment uses real child-owned Engram and Synapse images and root Compose can consume them.

---

## Phase 5: User Story 3 - Compare Development and Packaged Behavior (Priority: P3)

**Goal**: Keep local and packaged dogfood validation comparable so dogfooding reports can identify whether failures are environment-specific.

**Independent Test**: Run the documented smoke checklist against local dev and packaged Compose, then confirm the report template captures deployment path, service status, logs, config source, state freshness, and child packaging/root orchestration failure category.

### Implementation for User Story 3

- [X] T068 [P] [US3] Update local versus packaged behavior differences in `docs/dogfood-deployment.md`
- [X] T069 [P] [US3] Update smoke-test checklist for packaged Engram metadata discovery in `docs/dogfood-deployment.md`
- [X] T070 [P] [US3] Update smoke-test checklist for packaged Synapse reconciliation behavior in `docs/dogfood-deployment.md`
- [X] T071 [US3] Update failure-report checklist to include child packaging, root tagging/loading, Compose wiring, and runtime startup categories in `docs/dogfood-deployment.md`
- [X] T072 [US3] Update quickstart comparison steps in `specs/001-dogfood-deployment/quickstart.md`
- [X] T073 [US3] Update implementation notes with any known local-versus-packaged differences in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: Dogfooding reports can distinguish child packaging failures, root orchestration failures, and runtime service failures.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification, formatting, submodule hygiene, and final documentation consistency.

- [X] T074 [P] Run Engram Go formatting and tests for touched Go packaging or healthcheck code and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T075 [P] Run Engram Python formatting/checks for touched ingestion packaging and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T076 [P] Run Synapse Go formatting and tests for touched Go packaging or healthcheck code and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T077 Run root feature validation scripts in `specs/001-dogfood-deployment/validation/`
- [X] T078 Run root `git diff --check` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [X] T079 Confirm no generated runtime state, secrets, local database files, `.data/`, image archives, or `result*` symlinks are included in the final diff for `.gitignore`
- [X] T080 Commit Engram submodule packaging changes inside `engram/` before updating the root submodule pointer in `.gitmodules`
- [X] T081 Commit Synapse submodule packaging changes inside `synapse/` before updating the root submodule pointer in `.gitmodules`
- [X] T082 Update root implementation summary and verification notes in `specs/001-dogfood-deployment/implementation-notes.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks child image implementation.
- **US1 Local Dogfood Preservation (Phase 3)**: Can run after Setup; verifies prior local startup work did not regress.
- **US2 Packaged Deployment (Phase 4)**: Depends on Foundational; child package/image outputs must precede root deploy wiring.
- **US3 Comparison and Reporting (Phase 5)**: Depends on US2 documentation and validation paths.
- **Polish (Phase 6)**: Depends on selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Independent validation of existing local dogfood path; no dependency on US2.
- **US2 (P2)**: Main continuation; depends on Phase 2 child output contracts.
- **US3 (P3)**: Depends on US2 because comparison requires packaged Compose behavior.

### Within US2

- Engram and Synapse child package outputs can be implemented in parallel after Phase 2.
- Root `bin/deploy`, `flake.nix`, and `docker-compose.yml` updates depend on child output target names.
- Packaged validation depends on image build outputs and root image tagging.

---

## Parallel Opportunities

- T003, T004, T005, and T006 can run in parallel during setup.
- T009, T010, T011, and T012 can run in parallel after output names are chosen.
- T023 through T027 can run in parallel within Engram, except final `engram/flake.nix` wiring in T028.
- T033 through T037 can run in parallel within Synapse, except final `synapse/flake.nix` wiring in T038.
- T053 through T057 can run in parallel with root deploy script updates once image target names are known.
- T068 through T070 can run in parallel after packaged service behavior is known.
- T074, T075, and T076 can run in parallel during final verification.

---

## Parallel Example: User Story 2

```text
Task: "T023 Add Engram Go backend package derivation in engram/nix/backend.nix"
Task: "T026 Add Engram Python ingestion runtime derivation in engram/nix/ingestion.nix"
Task: "T033 Add Synapse Go command package derivation in synapse/nix/synapse.nix"
Task: "T034 Add Synapse worker container image derivation in synapse/nix/worker-container.nix"
Task: "T035 Add Synapse reconciler container image derivation in synapse/nix/reconciler-container.nix"
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete US1 preservation checks to avoid regressing local dogfood startup.
3. Complete the Engram child package/image outputs in US2.
4. Complete the Synapse child package/image outputs in US2.
5. Wire root `bin/deploy` and Compose to consume child image outputs.
6. Stop and validate the packaged deployment path before moving to US3.

### Incremental Delivery

1. Engram child images build and load.
2. Synapse child images build and load.
3. Root deploy consumes child outputs and tags platform images.
4. Compose starts real packaged services.
5. Documentation and smoke-test comparison classify failures accurately.

### Submodule Strategy

1. Make Engram packaging changes inside `engram/`.
2. Make Synapse packaging changes inside `synapse/`.
3. Commit child repo changes inside each submodule first.
4. Update the root repo only after child output contracts are stable.

---

## Notes

- All tasks use unchecked boxes because this is a new continuation task plan.
- Child repos own implementation packaging details; root Mind Palace owns platform orchestration.
- If a check cannot run locally because of sandbox, network, or container-runtime limits, record the reason in `specs/001-dogfood-deployment/implementation-notes.md`.
