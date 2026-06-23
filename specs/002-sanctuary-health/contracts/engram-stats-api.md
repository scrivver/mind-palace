# Engram Stats API Contract

## Endpoint

`GET /api/stats`

## Auth

Required. Bearer token issued by Reliquary (password mode) or validated via the
configured OIDC issuer.

## Response

```json
{
  "status": "healthy",
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
| `total_files` | `number` | Yes | Total indexed file count |
| `files_by_status` | `object` | Yes | Map of status → count |

## Real vs. Display Values

The following fields are computed from real DB queries:
- `total_files` — `SELECT COUNT(*) FROM files WHERE owner = $1`
- `files_by_status` — `SELECT status, COUNT(*) ... GROUP BY status`
- `status` — derived: if any failed > 0 → `"degraded"`, else `"healthy"`

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
