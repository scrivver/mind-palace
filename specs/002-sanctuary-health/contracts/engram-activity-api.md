# Engram Activity API Contract

## Endpoint

`GET /api/activity`

## Auth

Required. Bearer token from Authentik OIDC flow.

## Query Parameters

| Parameter | Type | Default | Max | Description |
|-----------|------|---------|-----|-------------|
| `limit` | `int` | 20 | 50 | Number of entries to return |
| `offset` | `int` | 0 | — | Pagination offset |

## Response

```json
{
  "entries": [
    {
      "id": "file_abc123",
      "icon": "task_alt",
      "description": "Metadata extraction complete for system_architecture_v2.pdf",
      "timestamp": "2026-06-22T10:30:00Z"
    }
  ],
  "total": 100
}
```

## Fields

| Field | Type | Always Present | Description |
|-------|------|----------------|-------------|
| `entries` | `array` | Yes | List of activity entries |
| `entries[].id` | `string` | Yes | File ID that generated the event |
| `entries[].icon` | `string` | Yes | Material Icon name for display |
| `entries[].description` | `string` | Yes | Human-readable event description |
| `entries[].timestamp` | `string` | Yes | RFC 3339 UTC timestamp |
| `total` | `number` | Yes | Total matching entries across all pages |

## Icon Mapping

The `icon` field maps from the file's current `status`:

| Status | Icon | Description Pattern |
|--------|------|-------------------|
| `pending` | `add_circle` | "New engram entry created: {filename}" |
| `processing` | `cloud_sync` | "Processing started for {filename}" |
| `ready` | `task_alt` | "Metadata extraction complete for {filename}" |
| `failed` | `error` | "Processing failed for {filename}" |
| fallback | `auto_fix_high` | "Neural mapping optimized for {filename}" |

## Error Responses

| Status | Body | Meaning |
|--------|------|---------|
| `200` | JSON | Success |
| `401` | plain text | Missing/invalid auth token |
| `500` | plain text | DB query failure or internal error |

## Go Handler Structure

```go
// in router.go — add to protected routes
mux.HandleFunc("GET /api/activity", s.handleActivity)

// in activity.go
func (s *Server) handleActivity(w http.ResponseWriter, r *http.Request) {
    owner := auth.UsernameFromContext(r.Context())
    limit := parseInt(r.URL.Query().Get("limit"), 20)
    offset := parseInt(r.URL.Query().Get("offset"), 0)

    // query: SELECT id, filename, status, updated_at FROM files
    // WHERE owner = $1 ORDER BY updated_at DESC LIMIT $2 OFFSET $3
    // query: SELECT COUNT(*) FROM files WHERE owner = $1

    entries := buildActivityEntries(rows)
    json.NewEncoder(w).Encode(ActivityResponse{Entries: entries, Total: total})
}
```
