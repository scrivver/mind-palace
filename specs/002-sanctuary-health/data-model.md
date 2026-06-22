# Data Model: Sanctuary Health Status Page

## Overview

Data models for the Status page UI state, Engram API responses, and
Reliquary API responses consumed by the Flutter client.

---

## 1. Flutter Client Models

These are Dart model classes used for deserializing API responses and
managing UI state.

### SanctuaryHealth (Page-level aggregate)

```dart
class SanctuaryHealth {
  final EngramEngineStatus engine;
  final SystemMetrics metrics;
  final StorageSummary storage;
  final ActivityFeed activity;
}
```

### EngramEngineStatus

| Field | Type | Description | Source |
|-------|------|-------------|--------|
| `status` | `String` | `"healthy"`, `"degraded"`, or `"error"` | Engram `/api/stats` |
| `efficiencyPct` | `int` | Display efficiency percentage | Engram `/api/stats` |
| `activeProcess` | `String` | Name of the active system process | Engram `/api/stats` |
| `syncFrequency` | `String` | Display sync frequency string | Engram `/api/stats` |
| `totalFiles` | `int` | Total number of indexed files | Engram `/api/stats` |
| `filesByStatus` | `Map<String, int>` | File counts per status | Engram `/api/stats` |

### SystemMetrics

| Field | Type | Description |
|-------|------|-------------|
| `latencyMs` | `int` | System latency in milliseconds |
| `syncSpeedMbps` | `double` | Sync speed in MB/s |
| `uptimePct` | `double` | Total uptime percentage |

### StorageSummary

| Field | Type | Description |
|-------|------|-------------|
| `totalSize` | `int` | Total used space in bytes |
| `capacity` | `int` | Display capacity in bytes (100 GB target) |
| `categories` | `List<StorageCategory>` | Per-breakdown items |

### StorageCategory

| Field | Type | Description |
|-------|------|-------------|
| `label` | `String` | Display name (Documents, Media, Research, Snippets) |
| `size` | `int` | Size in bytes (estimated from file counts) |
| `count` | `int` | File count in this category |
| `icon` | `IconData` | Material icon for the category |

### ActivityEntry

| Field | Type | Description | Source |
|-------|------|-------------|--------|
| `id` | `String` | Unique entry identifier | Engram `/api/activity` |
| `icon` | `String` | Material Icon name | Engram `/api/activity` |
| `description` | `String` | Human-readable event text | Engram `/api/activity` |
| `timestamp` | `DateTime` | Event time in UTC | Engram `/api/activity` |

### ActivityFeed

| Field | Type | Description |
|-------|------|-------------|
| `entries` | `List<ActivityEntry>` | Activity items for display |
| `total` | `int` | Total available entries (for "View Archive") |

---

## 2. Engram API Response Models (Go server-side)

### StatsResponse (`GET /api/stats`)

```go
type StatsResponse struct {
    Status         string         `json:"status"`          // "healthy" | "degraded" | "error"
    EfficiencyPct  int            `json:"efficiency_pct"`   // 0-100
    ActiveProcess  string         `json:"active_process"`   // display string
    SyncFrequency  string         `json:"sync_frequency"`   // display string
    LatencyMs      int            `json:"latency_ms"`       // computed or default
    SyncSpeedMbps  float64        `json:"sync_speed_mbps"`  // computed or default
    UptimePct      float64        `json:"uptime_pct"`       // computed or default
    TotalFiles     int            `json:"total_files"`      // from DB query
    FilesByStatus  map[string]int `json:"files_by_status"`  // from DB query
}
```

#### DB Queries

```sql
-- Total files
SELECT COUNT(*) FROM files WHERE owner = $1;

-- Files by status
SELECT status, COUNT(*) as count FROM files WHERE owner = $1 GROUP BY status;

-- Files by type (for activity description context)
SELECT filename, status, updated_at FROM files WHERE owner = $1 ORDER BY updated_at DESC LIMIT 1;
```

### ActivityResponse (`GET /api/activity`)

```go
type ActivityResponse struct {
    Entries []ActivityEntry `json:"entries"`
    Total   int             `json:"total"`
}

type ActivityEntry struct {
    ID          string `json:"id"`
    Icon        string `json:"icon"`
    Description string `json:"description"`
    Timestamp   string `json:"timestamp"` // RFC 3339
}
```

#### DB Query

```sql
SELECT f.id, f.filename, f.status, f.updated_at,
       COALESCE(d.name, 'unknown') as device_name
FROM files f
LEFT JOIN devices d ON f.device_id = d.id
WHERE f.owner = $1
ORDER BY f.updated_at DESC
LIMIT $2 OFFSET $3;
```

---

## 3. Reliquary API Response Model (consumed as-is)

### ReliquaryStats (`GET /api/stats`)

```json
{
  "total_size": 123456789,
  "file_count": 42,
  "by_type": {
    "image": 20,
    "video": 10,
    "application": 8,
    "text": 4
  },
  "by_month": {
    "2026/01": 5
  }
}
```

The Flutter client consumes this as `Map<String, dynamic>` via the existing
`ReliquaryService.getStats()` method. No new Dart model is required.

---

## 4. State Transitions

The Status page has no write operations. The only states are:

```
Loading → Loaded (all data available)
Loading → Degraded (some data failed)
Loading → Error (all data failed)
Loaded → Refreshing (pull-to-refresh)
```

Individual sections (engine, metrics, storage, activity) can be in different
states independently. The page displays whatever is available and shows
section-level error indicators for failed data sources.

---

## 5. Validation Rules

| Field | Rule |
|-------|------|
| `efficiencyPct` | Must be 0–100; otherwise clamp |
| `latencyMs` | Must be ≥ 0; otherwise show "--" |
| `syncSpeedMbps` | Must be ≥ 0; otherwise show "--" |
| `uptimePct` | Must be 0.0–100.0; otherwise show "--" |
| `timestamp` | Must be a valid UTC datetime; otherwise show "Unknown" |
| `totalSize` | Must be ≥ 0; otherwise show "0 B" |
| `by_type` categories | Non-existent keys default to 0 |
