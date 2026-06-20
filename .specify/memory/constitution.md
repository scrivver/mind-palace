<!--
Sync Impact Report
Version change: unratified template -> 1.0.0
Modified principles:
- Placeholder PRINCIPLE_1_NAME -> I. Nix-First Reproducibility
- Placeholder PRINCIPLE_2_NAME -> II. Component Boundaries and Submodule Ownership
- Placeholder PRINCIPLE_3_NAME -> III. Contract-Driven Event Integration
- Placeholder PRINCIPLE_4_NAME -> IV. Verification Proportional to Change
- Placeholder PRINCIPLE_5_NAME -> V. Runtime State and Secret Hygiene
Added sections:
- Monorepo Architecture Constraints
- Development Workflow and Quality Gates
Removed sections:
- Placeholder SECTION_2_NAME
- Placeholder SECTION_3_NAME
Templates requiring updates:
- UPDATED .specify/templates/plan-template.md
- UPDATED .specify/templates/spec-template.md
- UPDATED .specify/templates/tasks-template.md
- REVIEWED .specify/templates/commands/*.md (directory absent; no command templates to update)
Runtime guidance reviewed:
- REVIEWED AGENTS.md
- REVIEWED GEMINI.md
- REVIEWED README.md
- REVIEWED docs/next-steps-plan.md
- REVIEWED docs/reliquary-production-architecture.md
Follow-up TODOs:
- None
-->
# Mind Palace Constitution

## Core Principles

### I. Nix-First Reproducibility

All development, test, and infrastructure workflows MUST be expressible from the
root Nix environment. Plans MUST identify the exact Nix shell, launcher, or
component command used for verification. New dependencies MUST be added through
the appropriate Nix, Flutter, Go, or Python manifest and MUST NOT rely on
untracked host state.

Rationale: Mind Palace combines Flutter, Go, Python, and local infrastructure;
reproducible environments prevent component drift and make failures debuggable.

### II. Component Boundaries and Submodule Ownership

Changes MUST respect the ownership boundary of the root app, `reliquary/`,
`engram/`, and `synapse/`. Component-specific work MUST read that component's
README and agent guidance before design or implementation. Submodule changes
MUST be committed inside the submodule before the root repository updates its
pointer. Cross-component plans MUST name the owner, API, event, or storage
contract that connects each component.

Rationale: The repository is a monorepo orchestrator plus submodules; accidental
cross-boundary edits create hard-to-review coupling and broken submodule state.

### III. Contract-Driven Event Integration

Any feature that changes storage identity, file movement, ingestion, metadata,
authentication, or service-to-service communication MUST document the affected
contract before implementation. Event-producing changes MUST preserve the single
canonical file-event producer for each storage path and MUST include idempotency,
retry, and duplicate-delivery behavior. Shared fixtures or contract tests MUST
be updated when schemas change.

Rationale: Reliquary, Engram, and Synapse communicate through durable storage,
RabbitMQ, and shared data contracts; contract drift corrupts metadata and
reconciliation behavior.

### IV. Verification Proportional to Change

Every change MUST define and run the smallest meaningful verification set for
its blast radius. UI changes require Flutter analysis/tests when applicable and
screenshots for visible workflows. Go, Python, and ingestion changes require
focused unit, contract, or integration coverage beside the changed code.
Cross-service changes MUST include an integration path or an explicitly
documented reason it cannot be run locally.

Rationale: The system has multiple languages and queues; unverified changes can
pass in one component while breaking the end-to-end mnemonic workflow.

### V. Runtime State and Secret Hygiene

Runtime state MUST stay under `.data/` or documented external services and MUST
NOT be committed. Secrets, credentials, generated tokens, local database files,
MinIO data, and RabbitMQ state MUST remain outside source control. Configuration
changes MUST use documented environment variables with uppercase names and MUST
call out schema, secret, infrastructure, or migration impact in plans and PRs.

Rationale: Local infrastructure is intentionally easy to start; strict state and
secret boundaries keep development artifacts from becoming production risk.

## Monorepo Architecture Constraints

Mind Palace is a Nix-managed monorepo with a primary Flutter client in `app/`,
shared infrastructure in `infra/`, root launchers in `bin/`, shell definitions
in `shells/`, and Git submodules for `reliquary/`, `engram/`, and `synapse/`.
Plans MUST use the real repository layout rather than generic `src/` examples.

Reliquary owns storage API behavior and artifact-facing UI. Engram owns metadata
extraction, ingestion, and read-only metadata access. Synapse owns reconciliation
and transfer work. Root infrastructure owns local PostgreSQL, RabbitMQ, MinIO,
Caddy, Authentik, and orchestration scripts. Features that span these areas MUST
state which component changes first and how rollback preserves data and event
consistency.

## Development Workflow and Quality Gates

Feature specs MUST describe independently testable user journeys, affected
components, data contracts, state changes, and operational edge cases. Plans
MUST pass the Constitution Check before research and after design. Tasks MUST be
grouped by independently deliverable story and include exact file paths,
verification commands, documentation updates, and contract or migration tasks
where applicable.

Before submission, contributors MUST run the relevant component checks listed in
the plan or explain why a check was not run. Formatting MUST use `gofmt` for Go,
`dart format` plus `flutter analyze` for Dart, and the configured Python tooling
for ingestion code. Pull requests MUST summarize behavior, verification, linked
issues, UI screenshots when relevant, and any schema, infrastructure,
environment-variable, or submodule updates.

## Governance

This constitution supersedes conflicting feature plans, task templates, and
informal practices for Spec Kit work in this repository. Amendments require a
documented rationale, a semantic version bump, and a Sync Impact Report covering
affected templates and runtime guidance. Plans and reviews MUST verify
compliance with the current constitution before implementation proceeds.

Versioning policy:
- MAJOR: removes or redefines a principle in a backward-incompatible way.
- MINOR: adds a principle, governance section, or materially expands required
  practice.
- PATCH: clarifies language without changing required behavior.

Compliance review occurs during `/speckit-plan`, `/speckit-tasks`, code review,
and final verification. Any approved exception MUST be recorded in the plan's
Complexity Tracking section with the simpler alternative that was rejected.

**Version**: 1.0.0 | **Ratified**: 2026-06-21 | **Last Amended**: 2026-06-21
