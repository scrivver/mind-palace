# Feature Specification: Sanctuary Health Status Page

**Feature Branch**: `002-sanctuary-health`

**Created**: 2026-06-22

**Status**: Draft

**Input**: User description: "Status page according to the design in stitch mcp"

## User Scenarios & Testing

### User Story 1 - View System Health Dashboard (Priority: P1)

As a Mind Palace user, I can open the Status page from the sidebar to view the
overall health and performance metrics of my personal digital sanctuary so I can
understand whether the system is operating normally and spot issues before they
affect my workflow.

**Why this priority**: The Status page provides the system visibility that
dogfooding participants need to report failures effectively (matching
Dogfood Deployment FR-002 and SC-005).

**Independent Test**: Navigate to the Status page via sidebar and verify that
all health metric cards display meaningful data without error states.

**Acceptance Scenarios**:

1. **Given** the user is logged into Mind Palace, **When** they click "Status"
   in the sidebar, **Then** the Status page replaces the gallery view with the
   Sanctuary Health dashboard.
2. **Given** the status dashboard is displayed, **When** the page loads,
   **Then** the user sees the "Sanctuary Health" heading with a subtitle
   describing real-time optimization metrics.
3. **Given** all services are healthy, **When** the dashboard renders,
   **Then** the Engram Engine card shows an efficiency percentage, active
   process name, and sync frequency.
4. **Given** all services are healthy, **When** the dashboard renders,
   **Then** metric tiles show System Latency (ms), Sync Speed (MB/s), and
   Total Uptime (% or formatted duration).
5. **Given** storage data is available, **When** the dashboard renders,
   **Then** a Storage Capacity section shows total vs. used space with a
   breakdown by content category (Documents, Media, Research, Snippets).

---

### User Story 2 - View Recent Activity Feed (Priority: P2)

As a user, I can see recent system activity in a timeline on the Status page so
I can track what the system has been doing without navigating away from the
health overview.

**Why this priority**: The activity feed provides immediate context for recent
system behavior and complements the snapshot metrics from Story 1.

**Independent Test**: Verify recent activity entries appear with icon,
description text, and relative timestamps when the Status page loads.

**Acceptance Scenarios**:

1. **Given** there is recent system activity, **When** the Status page loads,
   **Then** a "Recent Activity" section displays entries with an icon, a
   one-line description, and a relative timestamp (e.g., "2 mins ago").
2. **Given** the user has more activities than the visible list, **When** the
   page renders, **Then** a "View Archive" link or button appears at the
   bottom of the activity section.

---

### User Story 3 - Handle Service Degradation (Priority: P3)

As a user, I can see when a service is not healthy so I can take appropriate
action without confusion.

**Why this priority**: Error states are less common but important for
operational trust.

**Independent Test**: Simulate a service failure and verify that the
dashboard shows an appropriate degraded state rather than an empty or broken
display.

**Acceptance Scenarios**:

1. **Given** a backend service returns an error, **When** the Status page
   loads or refreshes, **Then** the affected metric card shows a degraded
   state or error indicator rather than crashing or showing stale data.
2. **Given** no data is available at all (first launch), **When** the page
   loads, **Then** the user sees loading indicators or empty-state messaging
   rather than broken UI.

---

### Edge Cases

- What happens when the Engram API or Reliquary API is unreachable?
- What happens when storage stats are unavailable but the Engram engine is
  healthy?
- How does the activity feed behave when there are zero entries?
- What happens when the user switches away from the Status page and back?
- How are long activity descriptions truncated or handled?
- What happens when the system has been running for days — does uptime
  overflow or wrap?

## Requirements

### Functional Requirements

- **FR-001**: The system MUST display a "Status" navigation item in the sidebar
  that navigates to the Sanctuary Health page when selected.
- **FR-002**: The Status page MUST display a "Sanctuary Health" heading with a
  subtitle describing system optimization metrics.
- **FR-003**: The Status page MUST display an Engram Engine status card
  showing efficiency percentage, active process name, and sync frequency.
- **FR-004**: The Status page MUST display metrics for System Latency (ms),
  Sync Speed (MB/s), and Total Uptime (% or formatted duration).
- **FR-005**: The Status page MUST display Storage Capacity showing total vs.
  used space with a breakdown by content category.
- **FR-006**: The Status page MUST display a Recent Activity section with
  timestamped entries showing an icon, description, and relative time.
- **FR-007**: The Status page MUST show a loading indicator while data is
  being fetched.
- **FR-008**: The Status page MUST handle and display errors gracefully when
  backend services are unreachable, showing degraded UI rather than a crash.
- **FR-009**: The Status page MUST poll or refresh data to reflect current
  system state (manual refresh via pull-to-refresh), without polling interval.
- **FR-010**: The Recent Activity section MUST show a "View Archive" link when
  there are more entries than the displayed list limit.

### Key Entities

- **Health Metric**: A named measurement such as Latency, Sync Speed, or
  Uptime with a current value, unit, and optional status indicator.
- **Service Card**: A visual container for a service (e.g., Engram Engine)
  that shows its name, status level, process details, and sync configuration.
- **Storage Category**: A named bucket in the storage breakdown (Documents,
  Media, Research, Snippets) with a byte-count value.
- **Activity Entry**: A single recent event with an icon, description text,
  and relative timestamp.

### Contracts & Integration Impact

- **Affected Components**: `app/`, `engram/`
- **Contracts**:
  - Reliquary `GET /api/stats` — returns storage capacity and breakdown.
    Already exists; the Status page will consume this endpoint.
  - Engram `GET /api/health` — **new endpoint needed** for Engram engine
    status, active process, sync frequency, latency, and uptime metrics.
  - Engram `GET /api/activity` — **new endpoint needed** for recent activity
    feed entries.
- **State & Migrations**: None. The Status page is read-only.
- **Idempotency/Retry Behavior**: Repeated fetches of health/activity data
  are idempotent; no side effects.
- **Secrets/Configuration**: No new secrets. Existing Engram and Reliquary
  authentication tokens are reused.

## Success Criteria

### Measurable Outcomes

- **SC-001**: A user can open the Status page from the sidebar and see all
  health metric cards populated within 2 seconds on a healthy system.
- **SC-002**: The Status page renders without errors on first launch (fresh
  system with no data).
- **SC-003**: A user can identify whether the system is healthy or degraded
  within 3 seconds of opening the Status page.
- **SC-004**: The activity feed shows at least the 5 most recent entries and
  a "View Archive" link when more exist.
- **SC-005**: The Status page recovers gracefully when backend services return
  errors, showing degraded state instead of a blank or broken page.

## Assumptions

- The Reliquary `GET /api/stats` endpoint already exists and returns storage
  data suitable for the Storage Capacity section.
- New Engram endpoints (`GET /api/health`, `GET /api/activity`) will be added
  to support Engram engine metrics and the activity feed.
- The Status page is read-only and does not modify any system state.
- Desktop layout is the primary target; responsive behavior for smaller
  windows is a future concern.
- The existing sidebar navigation pattern and layout (sidebar + content area)
  will be reused.
