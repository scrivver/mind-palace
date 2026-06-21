#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
doc="$root/docs/dogfood-deployment.md"

test -f "$doc"
rg -q '^## Local Development Dogfood' "$doc"
rg -q '^## Packaged Compose Dogfood' "$doc"
rg -q '^## Dogfood Smoke Checklist' "$doc"
rg -q '^## Known Differences' "$doc"
rg -q '^## Failure Report Template' "$doc"
rg -q 'Deployment path: local-dev \| packaged-compose' "$doc"
rg -q 'State freshness: fresh \| reused \| migrated \| unknown' "$doc"
rg -q 'Do not include credentials' "$doc"
rg -q 'engram#api-container' "$doc"
rg -q 'engram#ingestion-container' "$doc"
rg -q 'synapse#worker-container' "$doc"
rg -q 'synapse#reconciler-container' "$doc"
rg -q 'child packaging | root image tagging/loading | Compose wiring | runtime startup' "$doc"

echo "dogfood docs contract ok"
