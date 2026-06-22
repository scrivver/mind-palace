# Research: Sanctuary Health Status Page

## Overview

Research findings for implementing the Sanctuary Health status page in the Mind
Palace Flutter app. Covers Engram API capabilities, Reliquary storage stats,
activity data sources, and UI patterns from the Stitch MCP design.

---

## 1. Existing Engram API — Health & Status

### Current State

Engram exposes a single health endpoint (`GET /api/health`) that returns a
static `{"status":"ok"}` response. No real metrics, no DB ping, no uptime
tracking.

**File**: `engram/backend/internal/api/health.go`

```go
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    w.Write([]byte(`{"status":"ok"}`))
}
```

### Available Data Source

The Engram PostgreSQL schema (`files`, `devices`, `tags`, `file_tags` tables)
supports:
- Total file count and size per owner
- Files by status (`pending`, `processing`, `ready`, `failed`)
- Files by MIME type (image, video, audio, pdf, other)
- Upload timestamps for activity feed

### New Endpoints Required

1. **`GET /api/stats`** — Returns engine metrics computed from DB queries:
   - `total_files`, `files_by_status`, and static display fields
   - No real latency/speed instrumentation in v1; uses display defaults

2. **`GET /api/activity`** — Returns recent file state transitions:
   - Derived from `files.updated_at` and `files.status` changes
   - Maps status changes to Material Icon names and descriptions

---

## 2. Existing Reliquary API — Storage Stats

### Current State

Reliquary has a mature `GET /api/stats` endpoint returning:

```json
{
  "total_size": 123456789,
  "file_count": 42,
  "by_type": {"image": 20, "video": 10, "application": 8, "text": 4},
  "by_month": {"2026/01": 5, "2026/03": 12}
}
```

**File**: `reliquary/backend/handler/handler.go` (line 675), backing storage
logic in `reliquary/backend/storage/stats.go`.

### How It Works

- Reads per-user file manifest from MinIO (`indexes/{username}/files.json`)
- Computes `total_size`, `file_count`, `by_type` (MIME first segment),
  `by_month` (from key path `YYYY/MM`)
- Auth-guarded via middleware; returns per-user data

### Usage in Status Page

The Flutter app already has `ReliquaryService.getStats()` — this is consumed
directly for the Storage Capacity section. The `by_type` map will be mapped
to the four display categories (Media, Documents, Research, Snippets).

---

## 3. Activity Feed Design

### Data Source

The only durable event-like data in Engram is the `files` table with
`updated_at` timestamps and `status` transitions. Each file change generates
a new `updated_at` value, allowing ordering by "most recently changed."

### Activity Entry Model

| Field | Source | Notes |
|-------|--------|-------|
| `id` | `file.id` | Unique file identifier |
| `icon` | Derived from status | Maps: new → `add_circle`, ready → `task_alt`, failed → `error`, in_progress → `cloud_sync` |
| `description` | Template + `file.filename` | e.g., "Metadata extraction complete for {filename}" |
| `timestamp` | `file.updated_at` | ISO 8601 UTC |

### Icon Mapping

| Status | Material Icon | Description Template |
|--------|---------------|---------------------|
| `pending` / new | `add_circle` | "New engram entry created: {filename}" |
| `processing` | `cloud_sync` | "Processing started for {filename}" |
| `ready` | `task_alt` | "Metadata extraction complete for {filename}" |
| `failed` | `error` | "Processing failed for {filename}" |
| (other) | `auto_fix_high` | "Neural mapping optimized for {filename}" |

---

## 4. Storage Category Mapping

The Stitch design shows four named categories. These map from Reliquary's
MIME-based type groups:

| Engram stats `by_type` | Display Label | Design Icon |
|------------------------|---------------|-------------|
| `application` | Documents | `description` |
| `image` + `video` + `audio` | Media | `perm_media` |
| `text` | Research | `auto_stories` |
| (everything else) | Snippets | `note` |

The Storage Capacity display uses:
- **Used**: `total_size` bytes from Reliquary stats
- **Capacity**: Display target of 100 GB (no real quota), computed as
  `max(total_size + 1 GB, 100 GB)` for a reasonable bar visualization
- **Per-category**: Sum of `by_type` sizes (not available in current API;
  will show file counts instead using `by_type` counts)

---

## 5. Stitch MCP Design — UI Layout

The Status page design shows this layout structure:

```
Sidebar |   Content Area
         |   [Sanctuary Health heading]
         |   [Subtitle: "Real-time optimization metrics..."]
         |
         |   [Engram Engine Card]
         |   | Efficiency: 100%, Active Process, Sync Frequency |
         |
         |   [Latency] [Sync Speed] [Total Uptime]
         |   42 ms     12.5 MB/s    99.9%
         |
         |   [Storage Capacity]
         |   |████████████░░░░| 84.2 GB / 100 GB
         |   Documents  45.0 GB
         |   Media      25.0 GB
         |   Research   10.0 GB
         |   Snippets   4.2 GB
         |
         |   [Recent Activity]
         |   ✓ Metadata extraction complete...  2 mins ago
         |   ✦ Neural mapping optimized...     14 mins ago
         |   ☁ Remote sync established...      42 mins ago
         |   🔒 Vault integrity scan...         1 hour ago
         |   + New engram entry created...      3 hours ago
         |   [View Archive →]
```

### Visual Tokens (from Design System)
- **Body font**: Inter (14px for body text)
- **Nav font**: Space Grotesk (14px for labels)
- **Metadata font**: Space Mono (12px for metrics and timestamps)
- **Cards**: 1px border, 12px radius, no elevation
- **Spacing**: 32px horizontal margins, 24px between sections
- **Layout**: Max-width 1440px centered content area

---

## 6. Flutter Component Tree

```
StatusScreen (StatefulWidget)
├── Stack
│   ├── RefreshIndicator
│   │   └── SingleChildScrollView
│   │       └── Column (crossAxisAlignment: start, maxWidth: 1440)
│   │           ├── Padding(32) → Header("Sanctuary Health", subtitle)
│   │           ├── SizedBox(32)
│   │           ├── EngramEngineCard (efficiency, process, frequency)
│   │           ├── SizedBox(24)
│   │           ├── Row → [LatencyTile, SyncSpeedTile, UptimeTile]
│   │           ├── SizedBox(24)
│   │           ├── StorageCapacitySection (total/used bar + breakdown)
│   │           ├── SizedBox(32)
│   │           ├── RecentActivitySection (list + "View Archive")
│   │           └── SizedBox(24)
│   └── Positioned(bottom) → FloatingActionButton (or none)
```

**FAB placement**: The Stitch design does not show a FAB on the Status page.
The existing FAB from the gallery should not appear.

---

## 7. Service Integration

### Data Fetching Strategy

```dart
class StatusPageData {
  final EngramStats engramStats;
  final Map<String, dynamic> reliquaryStats;
  final List<ActivityEntry> activity;
  final int activityTotal;
}

// Fetch all data in parallel
Future<StatusPageData> _loadData() async {
  final results = await Future.wait([
    _engram.getStats(),           // New method
    _reliquary.getStats(),         // Existing method
    _engram.getActivity(limit: 20), // New method
  ]);
  return StatusPageData(
    engramStats: results[0],
    reliquaryStats: results[1],
    activity: results[2].entries,
    activityTotal: results[2].total,
  );
}
```

### Error Handling

- Individual failures per data source (Engram stats, Reliquary stats, activity)
- Each section degrades independently
- If ALL sources fail, show a generic "Unable to load status" with retry
- If Engram stats fail but Reliquary works: show storage + activity with
  "Engine data unavailable" in the Engram card
