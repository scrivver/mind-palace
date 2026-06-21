#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
compose="$root/docker-compose.yml"

required_services=(
  postgres
  rabbitmq
  rabbitmq-setup
  minio
  minio-setup
  reliquary-api
  reliquary-thumbnail-worker
  engram-api
  engram-ingestion
  synapse-worker
  synapse-reconciler
  app
  ingress
)

test -f "$compose"
for service in "${required_services[@]}"; do
  rg -q "^[[:space:]]{2}${service}:" "$compose" || {
    echo "missing compose service: $service" >&2
    exit 1
  }
done

rg -q 'mind-palace-ingress:latest' "$compose"
rg -q 'mind-palace-app:latest' "$compose"
rg -q 'mind-palace-engram-api:latest' "$compose"
rg -q 'mind-palace-engram-ingestion:latest' "$compose"
rg -q 'mind-palace-synapse-worker:latest' "$compose"
rg -q 'mind-palace-synapse-reconciler:latest' "$compose"
rg -q 'engram-api-healthcheck' "$compose"
rg -q 'engram-ingestion-healthcheck' "$compose"
rg -q 'synapse-worker-healthcheck' "$compose"
rg -q 'synapse-reconciler-healthcheck' "$compose"
rg -q 'mind-palace-app-healthcheck' "$compose"
rg -q 'mc mb --ignore-existing' "$compose"
rg -q '/api/queues/%2F/' "$compose"
rg -q 'condition: service_completed_successfully' "$compose"
rg -q 'ENGRAM_API_URL: http://engram-api:8081$' "$compose"
rg -q '\$\{MIND_PALACE_PORT:-2080\}:2080' "$compose"
rg -q 'OIDC_REDIRECT_URI' "$compose"
rg -q 'OIDC_CLIENT_ID' "$compose"
rg -q '^volumes:' "$compose"

rg -q 'path:\$BUILD_ROOT/engram' "$root/bin/deploy"
rg -q 'api-container' "$root/bin/deploy"
rg -q 'ingestion-container' "$root/bin/deploy"
rg -q 'path:\$BUILD_ROOT/synapse' "$root/bin/deploy"
rg -q 'worker-container' "$root/bin/deploy"
rg -q 'reconciler-container' "$root/bin/deploy"
rg -q 'mind-palace-engram-api:latest' "$root/bin/deploy"
rg -q 'mind-palace-engram-ingestion:latest' "$root/bin/deploy"
rg -q 'mind-palace-synapse-worker:latest' "$root/bin/deploy"
rg -q 'mind-palace-synapse-reconciler:latest' "$root/bin/deploy"
rg -q 'mind-palace-app-container' "$root/bin/deploy"
rg -q 'mind-palace-app:latest' "$root/bin/deploy"

if rg -q 'mind-palace-engram-.*placeholder|mind-palace-synapse-.*placeholder' "$root/flake.nix"; then
  echo "root flake still contains Engram/Synapse placeholder containers" >&2
  exit 1
fi

published_count="$(rg -n '^[[:space:]]+ports:' "$compose" | wc -l)"
if [ "$published_count" -ne 1 ]; then
  echo "expected exactly one published service, found $published_count" >&2
  exit 1
fi

echo "packaged compose contract ok"
