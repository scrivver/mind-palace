# Implementation Plan: Sanctuary Health Status Page

**Branch**: `002-sanctuary-health` | **Date**: 2026-06-22 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/002-sanctuary-health/spec.md`

## Summary

Add a Status (Sanctuary Health) page to the Mind Palace Flutter app that
displays system health metrics, storage capacity, and recent activity. The page
replaces the current "Status — coming soon" placeholder at nav index 1. It
consumes the existing Reliquary `GET /api/stats` endpoint for storage data and
requires two new Engram API endpoints (`GET /api/stats`, `GET /api/activity`)
for engine metrics and activity feed. UI follows the Stitch MCP design with
metric cards, storage breakdown, and a timeline feed.

## Technical Context

**Language/Version**: Dart 3.x / Flutter 3.x for the client; Go 1.22+ for
Engram API extensions.

**Primary Dependencies**: `dio` (HTTP client, already in use), `fl_chart` or
similar for optional Storage Capacity visualization, existing `EngramService`
and `ReliquaryService` in the app.

**Storage**: Read-only. Engram stats come from PostgreSQL queries against the
`files`, `devices`, `tags`, and `file_tags` tables. Reliquary stats come from
the per-user MinIO file manifest via the existing `/api/stats` endpoint.

**Testing**:
- Flutter: `flutter test` for the new `StatusScreen` widget and service methods.
- Engram Go: `go test ./...` for new stats and activity handlers.
- E2E: Load the Status page in a running dev environment and verify cards
  populate.

**Target Platform**: Linux desktop (primary) and Flutter web (secondary for
packaged deployment).

**Project Type**: Flutter UI screen + Go API extensions in `engram/` submodule.

**Performance Goals**: Status page renders initial data within 2 seconds on a
healthy system with < 10k files. Activity feed shows last 20 entries.

**Constraints**: Page is read-only. Must reuse existing auth/token plumbing.
Must follow the established layout pattern (sidebar + content area).
Engram API must use stdlib `net/http` (no new router dependency).

**Scale/Scope**: Single-user desktop client view. Engram endpoints serve one
user at a time via auth context.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Nix-first reproducibility**: Verification uses `cd app && flutter analyze`,
  `cd app && flutter test`, and `cd engram && go test ./...`. Development and
  E2E validation run inside `nix develop` via `dev` or `start-app`.
- **Component boundaries**: Status UI belongs in `app/lib/screens/statis_screen.dart`
  (root app). Engram API extensions belong in `engram/backend/internal/api/`.
  No changes to `reliquary/`, `synapse/`, or `infra/`. Reliquary's existing
  `/api/stats` endpoint is consumed as-is.
- **Contract-driven integration**: Two new Engram API contracts:
  `GET /api/stats` and `GET /api/activity`. Both are read-only and use
  existing auth. No event, queue, or storage identity changes.
- **Verification proportional to change**: Flutter analysis + focused widget
  test for the screen. Go unit tests for new Engram handlers. Manual
  verification by opening the Status page in a running environment.
- **State and secret hygiene**: No state changes, no new secrets. Existing
  OIDC bearer-token auth is reused.

## Project Structure

### Documentation (this feature)

```text
specs/002-sanctuary-health/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Research findings
├── data-model.md        # Data model and entities
├── quickstart.md        # Validation guide
├── contracts/           # API contracts
│   ├── engram-stats-api.md
│   └── engram-activity-api.md
└── checklists/
    └── requirements.md
```

### Source Code (repository root)

```text
app/
  lib/
    screens/
      status_screen.dart     # New: Sanctuary Health page widget
    services/
      engram_service.dart    # Extended: add getStats(), getActivity()
main.dart                    # Updated: replace placeholder with StatusScreen
widgets/
  sidebar.dart               # Already has Status nav item — no change needed
engram/
  backend/
    internal/
      api/
        router.go            # Updated: register /api/stats and /api/activity
        stats.go             # New: GET /api/stats handler
        activity.go          # New: GET /api/activity handler
    internal/
      model/
        stats.go             # New: Stats response types
```

**Structure Decision**: New Flutter screen in `app/lib/screens/` following the
existing `gallery_screen.dart` pattern. New Engram handlers in
`engram/backend/internal/api/` following the existing `health.go` and
`files.go` pattern. No changes outside `app/` and `engram/`.

## Complexity Tracking

No constitution violations required.

---

## Phase 0: Research

### Unknowns from Technical Context

1. **Engram engine metrics format** — What specific fields should
   `GET /api/stats` return for the Engram Engine card (efficiency, active
   process, sync frequency)?
2. **Activity feed data source** — What constitutes a "recent activity" entry
   in Engram? Events can come from ingestion, file processing, sync, or
   reconciliation — which source is available now?
3. **Storage category mapping** — The Stitch design shows Documents, Media,
   Research, and Snippets. How should Reliquary's `by_type` map to these
   labels for display?

### Research Resolution

#### 1. Engram Engine Stats Format

**Decision**: The Engram `GET /api/stats` endpoint will return:

```json
{
  "status": "healthy|degraded|error",
  "efficiency_pct": 100,
  "active_process": "Recursive Indexing & Synaptic Linking",
  "sync_frequency": "432 Hz",
  "latency_ms": 42,
  "sync_speed_mbps": 12.5,
  "uptime_pct": 99.9,
  "total_files": 1024,
  "files_by_status": {
    "pending": 0,
    "processing": 1,
    "ready": 1020,
    "failed": 3
  }
}
```

**Rationale**: Static descriptive values are used for display-oriented fields
(active_process, sync_frequency) as they represent system configuration rather
than live metrics. Numeric fields (latency_ms, uptime_pct, total_files) are
computed from real data where the DB schema supports it (file counts, status
distribution) and static defaults where the current infrastructure doesn't
instrument the metric (latency, sync speed). This provides a meaningful display
now with clear extension points for real metrics later.

**Alternatives considered**:
- Return only real DB-derived metrics (file counts by status) and omit
  display fields — rejected because the design requires these visual elements.
- Implement actual RTT latency measurement and sync speed tracking — too
  heavyweight for v1 and would require significant instrumentation work.

#### 2. Activity Feed Data Source

**Decision**: The Engram `GET /api/activity` endpoint will return entries
derived from file state transitions (created, processed, failed) recorded in
the `files` table, ordered by `updated_at` descending:

```json
{
  "entries": [
    {
      "id": "evt_001",
      "icon": "auto_fix_high",
      "description": "Neural mapping optimized for Philosophy-Deep-Dive",
      "timestamp": "2026-06-22T10:30:00Z"
    }
  ],
  "total": 100
}
```

**Rationale**: File state transitions are the only durable event-like data
currently available in Engram. Each file's `status` and `updated_at` provide
the minimum viable activity trail. The icon field maps to Material Icons
names based on the type of state change (new file = `add_circle`, processing
complete = `task_alt`, failure = `error`). The Stitch design's "View Archive"
link is just a UI element that doesn't navigate yet — it appears when
`total > entries.length`.

**Alternatives considered**:
- Create a dedicated `activity_log` table and emit events from ingestion and
  reconciliation workers — more accurate but requires a migration and cross-
  component coordination beyond the v1 scope.
- Use the Reliquary upload timestamps — these only capture upload activity,
  not processing.

#### 3. Storage Category Mapping

**Decision**: Map Reliquary `/api/stats` `by_type` keys to display categories:

| by_type key | Display Label |
|-------------|---------------|
| `image`     | Media         |
| `video`     | Media         |
| `audio`     | Media         |
| `application` | Documents   |
| `text`      | Research      |
| (other)     | Snippets      |

Additionally, the total vs. used display comes from: used = `total_size`,
capacity = used + free estimate. Since the current infrastructure doesn't
enforce quotas, the "capacity" will be derived from the used size plus a
default allowance (100 GB display target).

**Rationale**: The Stitch design shows four named categories that don't map
1:1 to Reliquary's MIME-based `by_type` grouping. The mapping above gives a
reasonable visual match. The 100 GB total capacity is a display target — the
actual value could later come from a user quota system.

**Alternatives considered**:
- Use exact MIME sub-type (e.g., `application/pdf`) — more granular but
  doesn't match the design's 4-category breakdown.
- Store per-entity category manually — requires schema change and user
  configuration.

---

## Phase 1: Design & Contracts

### Data Model

See [data-model.md](./data-model.md) for full entity definitions.

Key entities:
- `SanctuaryHealth` — aggregate root for the full page state
- `EngramEngineStatus` — engine card data (efficiency, process, frequency)
- `SystemMetric` — a single named metric (latency, speed, uptime)
- `StorageSummary` — total/used/capacity + per-category breakdown
- `ActivityEntry` — a single activity feed item

### API Contracts

#### Engram `GET /api/stats`

Returns engine health and system metrics. Auth required. Response:

```json
{
  "status": "healthy",
  "efficiency_pct": 100,
  "active_process": "Recursive Indexing & Synaptic Linking",
  "sync_frequency": "432 Hz",
  "latency_ms": 42,
  "sync_speed_mbps": 12.5,
  "uptime_pct": 99.9,
  "total_files": 1024,
  "files_by_status": {
    "pending": 0,
    "processing": 1,
    "ready": 1020,
    "failed": 3
  }
}
```

See [contracts/engram-stats-api.md](./contracts/engram-stats-api.md).

#### Engram `GET /api/activity`

Returns recent activity entries. Auth required. Query params: `limit` (default
20, max 50), `offset` (default 0). Response:

```json
{
  "entries": [
    {
      "id": "evt_001",
      "icon": "task_alt",
      "description": "Metadata extraction complete for system_architecture_v2.pdf",
      "timestamp": "2026-06-22T10:30:00Z"
    }
  ],
  "total": 100
}
```

See [contracts/engram-activity-api.md](./contracts/engram-activity-api.md).

### Quickstart Guide

See [quickstart.md](./quickstart.md) for validation scenarios.
