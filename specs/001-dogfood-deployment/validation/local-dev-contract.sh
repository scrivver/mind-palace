#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"

required_processes=(
  postgres
  postgres-init
  rabbitmq
  minio
  minio-setup
  caddy
  authentik-server
  reliquary-api
  reliquary-thumbnail-worker
  engram-api
  engram-ingestion
  synapse-worker
  synapse-reconciler
  app
)

for process in "${required_processes[@]}"; do
  if ! rg -q "^[[:space:]]*${process}[[:space:]]*=" "$root/flake.nix" &&
     ! rg -q "^[[:space:]]*${process}[[:space:]]*=" "$root/infra" &&
     ! rg -q "^[[:space:]]*${process}[[:space:]]*=" "$root/flake.nix"; then
    echo "missing process definition: $process" >&2
    exit 1
  fi
done

rg -q 'dev-process-compose.yaml' "$root/flake.nix" "$root/shells/infra.nix" "$root/bin/dev"
rg -q -- '--dart-define=AUTHENTIK_URL=' "$root/bin/start-app"
rg -q -- '--dart-define=RELIQUARY_URL=' "$root/bin/start-app"
rg -q -- '--dart-define=ENGRAM_URL=' "$root/bin/start-app"
rg -q 'bin/start-app' "$root/flake.nix"
rg -q 'start-infra' "$root/bin/dev" && {
  echo "bin/dev must not require start-infra" >&2
  exit 1
}

echo "local dev contract ok"
