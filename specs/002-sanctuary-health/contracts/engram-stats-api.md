# Engram Stats API Contract

## Endpoint

`GET /api/stats`

## Auth

Required. Bearer token from Authentik OIDC flow.

## Response

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

## Fields

| Field | Type | Always Present | Description |
|-------|------|----------------|-------------|
| `status` | `string` | Yes | `"healthy"`, `"degraded"`, or `"error"` |
| `efficiency_pct` | `number` | Yes | Display efficiency (0–100) |
| `active_process` | `string` | Yes | Descriptive process name |
| `sync_frequency` | `string` | Yes | Display sync frequency |
| `latency_ms` | `number` | Yes | System latency in ms |
| `sync_speed_mbps` | `number` | Yes | Sync speed in MB/s |
| `uptime_pct` | `number` | Yes | Uptime percentage |
| `total_files` | `number` | Yes | Total indexed file count |
| `files_by_status` | `object` | Yes | Map of status → count |

## Real vs. Display Values

The following fields are computed from real DB queries:
- `total_files` — `SELECT COUNT(*) FROM files WHERE owner = $1`
- `files_by_status` — `SELECT status, COUNT(*) ... GROUP BY status`
- `status` — derived: if any failed > 0 → `"degraded"`, else `"healthy"`

The following fields use static display defaults (no instrumentation available):
- `efficiency_pct` — always `100` (could later reflect ingestion backlog)
- `active_process` — static label "Recursive Indexing & Synaptic Linking"
- `sync_frequency` — static label "432 Hz"
- `latency_ms` — computed as a simple DB round-trip or default `42`
- `sync_speed_mbps` — computed from recent ingestion throughput or default
- `uptime_pct` — could be computed from process start time or default `99.9`

## Error Responses

| Status | Body | Meaning |
|--------|------|---------|
| `200` | JSON | Success |
| `401` | plain text | Missing/invalid auth token |
| `500` | plain text | DB query failure or internal error |

## Go Handler Structure

```go
// in router.go — add to protected routes
mux.HandleFunc("GET /api/stats", s.handleStats)

// in stats.go
func (s *Server) handleStats(w http.ResponseWriter, r *http.Request) {
    owner := auth.UsernameFromContext(r.Context())
    // query files table
    // build response with static + computed fields
    json.NewEncoder(w).Encode(response)
}
```
