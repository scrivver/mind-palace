# Tasks: Dogfood Deployment

**Input**: Design documents from `/specs/001-dogfood-deployment/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Include focused test, analysis, contract, integration, or screenshot
tasks for changed behavior. If a relevant check cannot be run locally, record
the reason in `specs/001-dogfood-deployment/implementation-notes.md`.

**Organization**: Tasks are grouped by user story. This task plan focuses on
the current continuation: Engram OIDC helper endpoints, a real Mind Palace
Flutter web target, and a Compose-visible web UI while preserving the existing
local desktop dogfood path.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel when it touches different files and does not
  depend on an incomplete task
- **[Story]**: Which user story this task belongs to (`US1`, `US2`, `US3`)
- Include exact file paths in every task description

## Path Conventions

- **Root Flutter app**: `app/lib/`, `app/test/`, `app/web/`, `app/pubspec.yaml`
- **Root orchestration**: `flake.nix`, `nix/`, `bin/`, `docker-compose.yml`, `.env.example`
- **Engram submodule**: `engram/backend/`, `engram/nix/`, `engram/README.md`
- **Reliquary precedent**: `reliquary/frontend/`, `reliquary/backend/`, `reliquary/nix/`
- **Docs/spec artifacts**: `docs/`, `specs/001-dogfood-deployment/`

## Phase 1: Setup (Shared Context)

**Purpose**: Confirm component guidance and the existing implementation surface
before editing the app or Engram.

- [ ] T001 Review root app development guidance in `app/README.md`
- [ ] T002 Review Engram component guidance in `engram/README.md`
- [ ] T003 Review Engram agent guidance in `engram/CLAUDE.md`
- [ ] T004 [P] Inspect Reliquary Flutter web packaging precedent in `reliquary/nix/frontend-web.nix`
- [ ] T005 [P] Inspect Reliquary Caddy web image precedent in `reliquary/nix/web-container.nix`
- [ ] T006 [P] Inspect Reliquary browser auth precedent in `reliquary/frontend/lib/services/auth_service.dart` and `reliquary/frontend/lib/models/auth_config.dart`
- [ ] T007 [P] Inspect Reliquary OIDC helper handlers in `reliquary/backend/main.go`
- [ ] T008 Audit current Mind Palace app web blockers in `app/lib/auth_service.dart`, `app/lib/reliquary_service.dart`, `app/lib/engram_service.dart`, and `app/lib/screens/upload_screen.dart`
- [ ] T009 Audit current packaged app placeholder and routing in `flake.nix`, `nix/simple-container.nix`, `docker-compose.yml`, and `bin/deploy`
- [ ] T010 Record setup findings and any implementation constraints in `specs/001-dogfood-deployment/implementation-notes.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish shared contracts and platform-safe app boundaries that
must be stable before the user-story implementation tasks finish.

**CRITICAL**: Complete this phase before finalizing any story-specific web or
Compose behavior.

- [ ] T011 Define Engram auth helper response shapes in `engram/backend/internal/api/auth.go`
- [ ] T012 [P] Add Engram auth helper contract tests for `/api/auth/config` in `engram/backend/internal/api/auth_test.go`
- [ ] T013 [P] Add Engram auth helper contract tests for `/api/auth/oidc/discovery` and `/api/auth/oidc/token` in `engram/backend/internal/api/auth_test.go`
- [ ] T014 [P] Add Mind Palace app auth contract tests or widget-safe unit tests in `app/test/auth_service_test.dart`
- [ ] T015 Split the Mind Palace auth service interface from platform implementations in `app/lib/auth_service.dart`
- [ ] T016 Add native desktop auth implementation with existing loopback behavior in `app/lib/auth_service_native.dart`
- [ ] T017 Add web auth implementation scaffold with no `dart:io` imports in `app/lib/auth_service_web.dart`
- [ ] T018 Add conditional auth service export wiring in `app/lib/auth_service.dart`
- [ ] T019 Add web-safe file upload abstraction scaffold in `app/lib/upload_file.dart`
- [ ] T020 Add native upload file implementation in `app/lib/upload_file_native.dart`
- [ ] T021 Add web upload file implementation scaffold in `app/lib/upload_file_web.dart`
- [ ] T022 Update app dependency declarations for web auth and storage needs in `app/pubspec.yaml`
- [ ] T023 Update generated or checked-in Flutter web lock input in `app/pubspec.lock` and `app/pubspec.lock.json`

**Checkpoint**: Engram route contracts and app platform abstractions exist before service and UI wiring.

---

## Phase 3: User Story 1 - Start Local Dogfood Environment (Priority: P1)

**Goal**: Preserve one-command local dogfood startup and the Flutter Linux
desktop app path while adding web support.

**Independent Test**: Enter `nix develop`, run `dev`, confirm the generated
process-compose stack starts without a separate `start-infra`, then run the
desktop app path with generated Reliquary and Engram URLs injected.

### Tests and Validation for User Story 1

- [ ] T024 [P] [US1] Add or update launcher validation for desktop app URL injection in `specs/001-dogfood-deployment/validation/local-dev-contract.sh`
- [ ] T025 [P] [US1] Run local process-compose generation validation and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T026 [P] [US1] Run `cd app && flutter analyze` after platform split and record result in `specs/001-dogfood-deployment/implementation-notes.md`

### Implementation for User Story 1

- [ ] T027 [US1] Preserve generated Reliquary and Engram desktop URL injection in `bin/start-app`
- [ ] T028 [US1] Preserve full-stack process-compose app process environment in `shells/infra.nix`
- [ ] T029 [US1] Update app startup configuration parsing for desktop and web URL roots in `app/lib/main.dart`
- [ ] T030 [US1] Update Reliquary client base URL handling to avoid double `/api` prefixes in `app/lib/reliquary_service.dart`
- [ ] T031 [US1] Update Engram client base URL handling to avoid double `/api` prefixes in `app/lib/engram_service.dart`
- [ ] T032 [US1] Update upload screen imports to use the platform upload abstraction in `app/lib/screens/upload_screen.dart`
- [ ] T033 [US1] Document local desktop preservation and generated URL injection in `docs/dogfood-deployment.md`

**Checkpoint**: Local dogfood remains usable through `dev` and the desktop app still launches with generated service URLs.

---

## Phase 4: User Story 2 - Run Packaged Dogfood Deployment (Priority: P2)

**Goal**: Build and run packaged Compose with a real browser-accessible Mind
Palace web UI and Engram OIDC helper endpoints.

**Independent Test**: Build `.#mind-palace-app-container`, run `./bin/deploy`,
run `docker compose config --quiet`, start Compose, open the public entry point,
and probe `/`, `/api/engram/health`, and `/api/engram/auth/config` through the
same public origin.

### Engram Auth Helper Endpoints

- [ ] T034 [P] [US2] Add OIDC redirect URI configuration support in `engram/backend/internal/config/config.go`
- [ ] T035 [P] [US2] Add auth config response types and helpers in `engram/backend/internal/api/auth.go`
- [ ] T036 [US2] Implement `GET /api/auth/config` in `engram/backend/internal/api/auth.go`
- [ ] T037 [US2] Implement `GET /api/auth/oidc/discovery` in `engram/backend/internal/api/auth.go`
- [ ] T038 [US2] Implement `POST /api/auth/oidc/token` in `engram/backend/internal/api/auth.go`
- [ ] T039 [US2] Register public Engram auth helper routes before protected routes in `engram/backend/internal/api/router.go`
- [ ] T040 [US2] Update Engram backend startup to pass config into API routes in `engram/backend/main.go`
- [ ] T041 [US2] Add Engram auth helper documentation and environment variables in `engram/README.md`
- [ ] T042 [US2] Ensure Engram API container exposes OIDC redirect configuration in `engram/nix/api-container.nix`

### Mind Palace Flutter Web App

- [ ] T043 [P] [US2] Add Flutter web host files in `app/web/index.html`
- [ ] T044 [P] [US2] Add web auth model types for Engram auth config and token responses in `app/lib/auth_models.dart`
- [ ] T045 [US2] Implement Engram auth config discovery for web login in `app/lib/auth_service_web.dart`
- [ ] T046 [US2] Implement browser PKCE authorization redirect in `app/lib/auth_service_web.dart`
- [ ] T047 [US2] Implement `/callback` token exchange through Engram helper endpoint in `app/lib/auth_service_web.dart`
- [ ] T048 [US2] Implement web token persistence and logout behavior in `app/lib/auth_service_web.dart`
- [ ] T049 [US2] Wire auth state initialization and callback handling into `app/lib/main.dart`
- [ ] T050 [US2] Complete web upload file handling in `app/lib/upload_file_web.dart`
- [ ] T051 [US2] Update app UI upload flow to support browser-selected files in `app/lib/screens/upload_screen.dart`
- [ ] T052 [US2] Update app service clients to use same-origin packaged roots in `app/lib/reliquary_service.dart` and `app/lib/engram_service.dart`
- [ ] T053 [US2] Run `cd app && flutter test` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T054 [US2] Run `cd app && flutter build web` or the Nix equivalent and record result in `specs/001-dogfood-deployment/implementation-notes.md`

### Nix Web Package and Container

- [ ] T055 [P] [US2] Add root Flutter web package derivation in `nix/app-web.nix`
- [ ] T056 [P] [US2] Add root Caddy web container derivation in `nix/app-web-container.nix`
- [ ] T057 [US2] Wire `mind-palace-app-web` and `mind-palace-app-container` package outputs into `flake.nix`
- [ ] T058 [US2] Add Caddy routing for `/`, `/callback`, `/health`, `/api/reliquary/*`, and `/api/engram/*` in `nix/app-web-container.nix`
- [ ] T059 [US2] Add web app healthcheck that verifies static shell and proxied API health in `nix/app-web-container.nix`
- [ ] T060 [US2] Ensure the root web image does not include source bind mounts, Flutter dev server startup, or baked secrets in `nix/app-web-container.nix`

### Compose and Deploy Wiring

- [ ] T061 [US2] Replace the packaged app placeholder with `mind-palace-app:latest` service wiring in `docker-compose.yml`
- [ ] T062 [US2] Route the public Compose port to the web app or retained ingress service in `docker-compose.yml`
- [ ] T063 [US2] Configure Reliquary and Engram same-origin API proxy targets in `docker-compose.yml`
- [ ] T064 [US2] Add or update packaged auth environment for Engram and app web redirects in `docker-compose.yml`
- [ ] T065 [US2] Add `MIND_PALACE_PORT`, public origin, and OIDC redirect placeholders in `.env.example`
- [ ] T066 [US2] Update root `bin/deploy` to build and load `.#mind-palace-app-container`
- [ ] T067 [US2] Update root `bin/deploy` image verification to require `mind-palace-app:latest`
- [ ] T068 [US2] Update packaged validation script for web image and auth route contracts in `specs/001-dogfood-deployment/validation/packaged-compose-contract.sh`
- [ ] T069 [US2] Update packaged documentation for browser UI startup and auth discovery in `docs/dogfood-deployment.md`

### Packaged Validation

- [ ] T070 [US2] Run Engram Go tests for auth helper endpoints with `cd engram/backend && go test ./...` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T071 [US2] Run `nix build .#mind-palace-app-container --no-link --print-out-paths` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T072 [US2] Run root `./bin/deploy` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T073 [US2] Run `docker compose config --quiet` or equivalent Podman command and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T074 [US2] Start packaged Compose and verify `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/` in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T075 [US2] Verify packaged Engram health through `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/engram/health` in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T076 [US2] Verify packaged Engram auth config through `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/engram/auth/config` in `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: Packaged Compose serves the real Mind Palace web UI and exposes Engram metadata/auth routes through one public origin.

---

## Phase 5: User Story 3 - Compare Development and Packaged Behavior (Priority: P3)

**Goal**: Keep local and packaged dogfood validation comparable so participants
can identify whether failures are local-only, packaged-only, auth-specific, or
web-target-specific.

**Independent Test**: Run the documented smoke checklist against local dev and
packaged Compose, then confirm the report template captures deployment path,
service status, logs, config source, state freshness, and web/OIDC failure
category.

### Implementation for User Story 3

- [ ] T077 [P] [US3] Update local versus packaged behavior differences for desktop and web UI in `docs/dogfood-deployment.md`
- [ ] T078 [P] [US3] Update smoke-test checklist for Engram auth config and OIDC discovery in `docs/dogfood-deployment.md`
- [ ] T079 [P] [US3] Update smoke-test checklist for packaged web upload and metadata discovery in `docs/dogfood-deployment.md`
- [ ] T080 [P] [US3] Update quickstart browser UI and auth helper validation steps in `specs/001-dogfood-deployment/quickstart.md`
- [ ] T081 [US3] Update failure-report checklist with web compile, Caddy proxy, OIDC helper, and browser callback categories in `docs/dogfood-deployment.md`
- [ ] T082 [US3] Add any known local-versus-packaged differences discovered during validation to `specs/001-dogfood-deployment/implementation-notes.md`

**Checkpoint**: Dogfooding reports can distinguish desktop local issues from packaged web, proxy, and Engram OIDC helper issues.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verification, formatting, submodule hygiene, and final
documentation consistency.

- [ ] T083 [P] Run `gofmt` on touched Engram Go files in `engram/backend/`
- [ ] T084 [P] Run `dart format .` in `app/`
- [ ] T085 [P] Run root feature validation scripts in `specs/001-dogfood-deployment/validation/`
- [ ] T086 Run root `git diff --check` and record result in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T087 Confirm no generated runtime state, secrets, local database files, `.data/`, image archives, or `result*` symlinks are included in the final diff for `.gitignore`
- [ ] T088 Commit Engram submodule auth-helper changes inside `engram/` before updating the root submodule pointer in `.gitmodules`
- [ ] T089 Update root implementation summary and verification notes in `specs/001-dogfood-deployment/implementation-notes.md`
- [ ] T090 Run the packaged and local quickstart checks from `specs/001-dogfood-deployment/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; can start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks final story implementation.
- **US1 Local Dogfood Preservation (Phase 3)**: Depends on platform abstractions from Phase 2.
- **US2 Packaged Web Deployment (Phase 4)**: Depends on Phase 2; Engram helper endpoints, web app implementation, Nix packaging, and Compose wiring can proceed in that order.
- **US3 Comparison and Reporting (Phase 5)**: Depends on US1 and US2 validation behavior being known.
- **Polish (Phase 6)**: Depends on selected user stories being complete.

### User Story Dependencies

- **US1 (P1)**: MVP preservation path; can complete after Phase 2 without US2.
- **US2 (P2)**: Main web/OIDC delivery; depends on Phase 2 contracts and platform abstractions.
- **US3 (P3)**: Depends on US1 and US2 because comparison requires both deployment paths.

### Within US2

- Engram auth helper tests should exist before endpoint implementation.
- App platform split must land before web auth and upload code.
- Nix web package can start after web build inputs are stable.
- Compose/deploy wiring depends on the `mind-palace-app-container` output name.
- Packaged validation depends on image build/load and Compose configuration.

---

## Parallel Opportunities

- T004, T005, T006, and T007 can run in parallel during setup.
- T012, T013, and T014 can run in parallel after route contracts are defined.
- T034, T035, T043, T044, T055, and T056 can run in parallel across Engram, app, and Nix files.
- T077, T078, T079, and T080 can run in parallel once validation behavior is known.
- T083, T084, and T085 can run in parallel during final verification.

---

## Parallel Example: User Story 2

```text
Task: "T034 Add OIDC redirect URI configuration support in engram/backend/internal/config/config.go"
Task: "T043 Add Flutter web host files in app/web/index.html"
Task: "T055 Add root Flutter web package derivation in nix/app-web.nix"
Task: "T056 Add root Caddy web container derivation in nix/app-web-container.nix"
```

---

## Implementation Strategy

### MVP First

1. Complete Phase 1 and Phase 2.
2. Complete US1 to prove the desktop local dogfood path did not regress.
3. Stop and validate `dev`, generated service URLs, and `flutter analyze`.

### Incremental Delivery

1. Add Engram auth helper endpoint tests and implementation.
2. Add platform-safe app auth and upload abstractions.
3. Add the Flutter web build and verify it compiles.
4. Add the Nix web package/container and build `.#mind-palace-app-container`.
5. Wire Compose and deploy script to expose the real web UI.
6. Run packaged smoke checks through the public origin.

### Submodule Strategy

1. Make Engram API changes inside `engram/`.
2. Commit Engram submodule changes before updating the root pointer.
3. Keep Mind Palace root responsible for `app/`, `nix/`, `docker-compose.yml`, `.env.example`, `bin/deploy`, and docs.

---

## Notes

- All tasks are unchecked because this is the executable task list for the current web/OIDC continuation.
- Engram owns OIDC helper API semantics; the root app consumes those routes.
- The packaged app container must serve a real Flutter web bundle, not a placeholder response or Flutter dev server.
- If a check cannot run locally because of sandbox, network, or container-runtime limits, record the reason in `specs/001-dogfood-deployment/implementation-notes.md`.
