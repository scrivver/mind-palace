# Feature Specification: Dogfood Deployment

**Feature Branch**: `test-speckit`

**Created**: 2026-06-21

**Status**: Draft

**Input**: User description: "the entire mind palace project development should arrive to a stage where dogfooding is needed. I need 2 ways that the project can be deploy and tested easity. 1) The dev shell, currently is using manual start-infra command, and dev command to bring the backends and frontends up. But I want to change that to follow the pattern of reliquary, which is a single dev command bring up all the services using process compose. 2) I need you to follow the pattern of reliquary, to have properly documented docker compose file, as well as the nix shells to build the container."

## Clarifications

### Session 2026-06-21

- Q: For first packaged delivery, must Engram and Synapse run real service images or may placeholders satisfy the deployment? → A: Packaged deployment must run real Reliquary, Engram, Synapse, app, and ingress service images for first delivery.
- Q: How should the primary Mind Palace app be exposed for packaged dogfooding? → A: Packaged Compose should serve a real Flutter web build of the Mind Palace app while preserving the local Flutter desktop dev target.
- Q: How should browser clients discover identity provider settings? → A: Reliquary exposes `/api/auth/config` describing enabled auth methods (password, OIDC, proxy, none). When OIDC is enabled it returns the issuer and client ID; the Flutter app performs direct OIDC discovery against that issuer. Engram no longer exposes auth config or OIDC helper endpoints.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Start Local Dogfood Environment (Priority: P1)

As a project developer, I can start the full Mind Palace dogfooding environment
with one development command so I can use the product locally without remembering
separate infrastructure and application startup steps.

**Why this priority**: This is the fastest path to dogfooding. If local startup
remains manual and multi-step, contributors will avoid using the full system
during normal development.

**Independent Test**: From a clean checkout with prerequisites installed, run the
documented development startup command and confirm all expected user-facing and
backend services become reachable without separately running an infrastructure
startup command.

**Acceptance Scenarios**:

1. **Given** a developer has entered the project development environment, **When**
   they run the documented dogfood startup command, **Then** shared services,
   backend services, workers, and the primary user interface start together and
   expose a clear status view.
2. **Given** a required service fails during startup, **When** the developer
   checks the process status and logs, **Then** the failure identifies the
   service name, the failed command, and the next recovery action.
3. **Given** the local dogfood environment is running, **When** the developer
   stops it using the documented shutdown path, **Then** all managed processes
   stop and reusable local runtime state remains in the documented state
   location.

---

### User Story 2 - Run Packaged Dogfood Deployment (Priority: P2)

As a maintainer, I can build and run a packaged Mind Palace deployment using a
documented compose workflow so I can smoke-test the system in an environment that
resembles real usage more closely than live development processes.

**Why this priority**: The project needs a repeatable deployment path before
dogfooding feedback can be trusted. Maintainers must be able to validate the
same service boundaries and packaged artifacts that users will receive.

**Independent Test**: Follow the packaged deployment guide from build through
startup, then complete a smoke test that reaches the public entry point and
verifies the core artifact, metadata, and movement workflows are available.

**Acceptance Scenarios**:

1. **Given** a maintainer has a checkout and local container runtime, **When**
   they follow the packaged deployment documentation, **Then** all required
   application images are built or loaded and the compose deployment starts from
   documented configuration.
2. **Given** the packaged deployment is running, **When** the maintainer opens
   the public entry point, **Then** the primary Mind Palace experience is
   available without exposing internal infrastructure services directly.
3. **Given** the maintainer needs to inspect or reset the deployment, **When**
   they use documented commands, **Then** they can view service health, logs,
   persistent data locations, and shutdown steps without reading source code.

---

### User Story 3 - Compare Development and Packaged Behavior (Priority: P3)

As a dogfooding participant, I can use the documented verification checklist for
both deployment paths so I can report whether a failure is specific to local
development or also present in the packaged deployment.

**Why this priority**: Dogfooding is only useful when feedback is reproducible.
Clear parity checks reduce time spent triaging environment-specific failures.

**Independent Test**: Run the documented smoke test against both deployment
paths and confirm the expected result, known differences, and failure-reporting
details are recorded.

**Acceptance Scenarios**:

1. **Given** both deployment paths are available, **When** a participant runs the
   dogfood smoke test in each path, **Then** the same core user workflows can be
   verified and any intentional differences are documented.
2. **Given** a smoke test fails in one path, **When** the participant files a
   report, **Then** the report includes the deployment path, service status,
   relevant logs, configuration source, and data reset status.

### Edge Cases

- Startup is requested when ports or local service names are already in use.
- A developer interrupts startup before all services are healthy.
- A backend, worker, or infrastructure service exits after the environment has
  already reported as started.
- Persistent local state exists from a previous version and may require reset,
  migration, or explicit reuse.
- Required secrets or configuration values are missing, weak defaults, or
  unsuitable for anything beyond local dogfooding.
- The packaged deployment is started without built images or with stale images.
- A smoke test creates duplicate events or retries work after a restart.
- A participant needs to run only cleanup without restarting the environment.
- Logs contain sensitive values that must not be copied into reports.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a single documented local dogfood startup
  command that starts shared infrastructure, backends, workers, and the primary
  user interface together.
- **FR-002**: The local startup command MUST expose a service status and log
  workflow that lets developers identify healthy, starting, failed, and stopped
  services.
- **FR-003**: The local dogfood workflow MUST include a documented shutdown path
  that stops all managed services without deleting reusable runtime state by
  default.
- **FR-004**: The local dogfood workflow MUST document how to reset local
  runtime state when a clean environment is required.
- **FR-005**: The packaged dogfood workflow MUST provide documented configuration
  files and commands to build, load, start, inspect, stop, and reset the packaged
  deployment.
- **FR-005a**: The first packaged dogfood delivery MUST run real Reliquary,
  Engram, Synapse, primary app, and ingress service images; placeholder
  containers MUST NOT satisfy packaged deployment acceptance criteria.
- **FR-006**: The packaged dogfood workflow MUST keep internal infrastructure
  services private by default and expose only the documented public entry point
  unless a maintainer explicitly chooses otherwise.
- **FR-007**: The packaged dogfood documentation MUST identify all required
  configuration values, which values are safe defaults, and which values must be
  changed before sharing or exposing the deployment.
- **FR-008**: Both deployment paths MUST include the same smoke-test checklist
  covering startup, sign-in or access, artifact storage, metadata discovery, and
  transfer or reconciliation behavior where those capabilities are present.
- **FR-009**: Both deployment paths MUST document expected persistent state
  locations and distinguish reusable data from disposable generated data.
- **FR-010**: The workflows MUST provide clear failure-reporting guidance,
  including service status, logs, configuration source, and whether runtime state
  was fresh or reused.
- **FR-011**: The packaged deployment MUST be documented well enough that a
  maintainer can complete a full build-and-start cycle without using the local
  live-development startup command.
- **FR-012**: The local and packaged dogfood workflows MUST call out known
  differences so participants do not mistake intentional development behavior for
  deployment defects.
- **FR-013**: The packaged deployment MUST expose a real browser-accessible Mind
  Palace web UI built from the primary Flutter app; a placeholder app container
  MUST NOT satisfy packaged deployment acceptance criteria.
- **FR-014**: The local development workflow MUST preserve the Flutter Linux
  desktop app path and continue injecting generated service URLs into the app at
  launch time.
- **FR-015**: Reliquary MUST expose client-consumable auth configuration via
  `GET /api/auth/config` so the Mind Palace app can discover the enabled auth
  methods. When OIDC is enabled, Reliquary returns the issuer URL and client ID,
  and the Flutter app completes browser token exchange directly with the OIDC
  provider. Engram MUST validate the resulting Bearer token using the shared
  JWT secret or configured OIDC issuer URL.
- **FR-016**: The packaged web UI MUST use the documented public Compose origin
  for Reliquary and Engram API access, avoiding Docker-internal hostnames in
  browser code.

### Key Entities *(include if feature involves data)*

- **Deployment Path**: A supported way to run the whole project for dogfooding,
  either local development or packaged deployment.
- **Service Group**: A named set of related processes such as shared
  infrastructure, application backends, workers, and user interface.
- **Runtime Configuration**: The documented values used to start a deployment,
  including ports, credentials, persistent data locations, and public entry
  points.
- **Dogfood Smoke Test**: A repeatable verification checklist that proves the
  environment is usable for real project feedback.
- **Failure Report**: The minimum diagnostic information a participant provides
  when a dogfood deployment path does not start or a smoke test fails.
- **Web App Runtime**: The packaged browser UI served from the public Compose
  entry point and built from the primary Flutter app.
- **Auth Discovery Contract**: The Reliquary API endpoint that advertises
  enabled auth methods (password, OIDC, proxy, none) and OIDC client
  configuration to the Mind Palace app.

### Contracts & Integration Impact *(include if feature crosses components)*

- **Affected Components**: root development workflow, root infrastructure,
  Reliquary, Engram, Synapse, primary app, and project documentation.
- **Contracts**: Startup, shutdown, service-health, configuration, web routing,
  OIDC discovery/token helper, persistent state, and smoke-test reporting
  contracts. Existing application data and event contracts must remain
  compatible unless a later plan explicitly scopes a contract change.
- **State & Migrations**: Local runtime state and packaged persistent volumes
  must be documented. Any migration or reset requirement must be visible before
  startup changes existing data.
- **Idempotency/Retry Behavior**: Re-running startup after an interrupted or
  failed attempt must either resume safely or report the exact cleanup needed.
  Smoke tests must account for duplicate event delivery and restarted services.
- **Secrets/Configuration**: Local-only defaults may be convenient, but packaged
  deployment documentation must identify values that require replacement before
  shared use.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can start the full local dogfood environment from a
  clean checkout in 10 minutes or less after prerequisites are installed.
- **SC-002**: At least 90% of routine local dogfood startup attempts require only
  one command after entering the development environment.
- **SC-003**: A maintainer can complete the packaged build, startup, health
  check, and shutdown workflow in 30 minutes or less on a prepared workstation.
- **SC-004**: The documented smoke test verifies at least one user-visible
  workflow across storage, metadata, and movement or reconciliation behavior.
- **SC-005**: When a service fails to start, a participant can identify the
  failed service and locate relevant logs in under 2 minutes using documented
  steps.
- **SC-006**: New dogfooding reports include deployment path, service status,
  configuration source, and state freshness in at least 90% of submitted cases.
- **SC-007**: A maintainer can open the packaged public entry point in a browser
  and see the Mind Palace web UI within 2 minutes after `docker compose up -d`
  reports healthy services.
- **SC-008**: The packaged web smoke test can reach Reliquary auth config,
  Reliquary storage routes, and Engram metadata routes through the same public
  origin without browser CORS errors.

## Assumptions

- Dogfooding participants are maintainers or developers working from a local
  checkout with project prerequisites installed.
- The local development path prioritizes fast iteration and reusable state over
  production hardening.
- The packaged path targets single-host dogfooding and smoke testing, not final
  horizontal-scaling guarantees.
- Existing Reliquary deployment patterns are the model for documentation quality,
  service separation, and build-before-run flow.
- Existing application contracts should remain unchanged unless later planning
  proves a contract change is necessary.
- Runtime state may be reused by default, but the reset workflow must be clear
  and explicit.
