# Quickstart: Backend Display Paths

## Prerequisites

From repository root:

```bash
nix develop
git submodule update --init --recursive
```

## Focused Verification

Reliquary backend:

```bash
cd reliquary/backend && go test ./...
```

Engram ingestion:

```bash
cd engram && bin/test-ingest
```

Engram backend:

```bash
cd engram/backend && go test ./...
```

## Manual Contract Check

1. Upload or simulate a Reliquary folder upload with relative path:

```text
docs/myfile.pdf
```

2. Verify the emitted event contains:

```json
{
  "filename": "docs/myfile.pdf",
  "file_path": "files/alice/2026/07/docs/myfile.pdf"
}
```

3. Verify Engram `GET /api/files` returns:

```json
{
  "filename": "docs/myfile.pdf",
  "file_path": "files/alice/2026/07/docs/myfile.pdf"
}
```

Expected result: the Flutter gallery can group the file under folder `docs` using `filename`, without inspecting `file_path`.

## Validation Results

Recorded during implementation:

```bash
cd reliquary/backend && XDG_CACHE_HOME=/tmp/codex-cache GOCACHE=/tmp/reliquary-go-cache go test ./handler ./event
cd reliquary/backend && XDG_CACHE_HOME=/tmp/codex-cache GOCACHE=/tmp/reliquary-go-cache go test ./...
cd engram/ingestion && uv run python -m unittest tests.test_handler
cd engram/ingestion && uv run python -m py_compile tests/test_handler.py worker/handler.py worker/db.py
cd engram/backend && XDG_CACHE_HOME=/tmp/codex-cache GOCACHE=/tmp/engram-go-cache go test ./internal/api
cd engram/backend && XDG_CACHE_HOME=/tmp/codex-cache GOCACHE=/tmp/engram-go-cache go test ./...
```

Notes:

- `cd engram && python -m unittest ingestion.tests.test_handler` was not usable in this shell because the ingestion dependencies are scoped to `engram/ingestion`; the equivalent `uv run` command from `engram/ingestion` passed.
- `ruff` was not available in the current shell, so Python formatter/lint verification was not run here.
- `cd engram && bin/test-ingest` was not run because it requires an active dev-shell infrastructure session with `DATA_DIR`, PostgreSQL, RabbitMQ, MinIO, watcher, ingestion worker, and API already running.

### Convergence Re-Validation (2026-07-12)

Re-verified after closing the convergence gaps (T036-T039):

```bash
cd reliquary/backend && XDG_CACHE_HOME=/tmp/codex-cache GOCACHE=/tmp/reliquary-go-cache go test ./...
cd engram/ingestion && uv run python -m unittest tests.test_handler
cd engram/backend && XDG_CACHE_HOME=/tmp/codex-cache GOCACHE=/tmp/engram-go-cache go test ./...
gofmt -l reliquary/backend/handler/handler.go reliquary/backend/handler/handler_test.go
```

All passed. Additional coverage added: backslash traversal and folder-path sanitization tests, duplicate-folder-upload display-path preservation, and a folder-style rename display-path test.
