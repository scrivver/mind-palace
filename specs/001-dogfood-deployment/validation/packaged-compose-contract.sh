#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
compose="$root/docker-compose.yml"

required_services=(
  postgres
  rabbitmq
  minio
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
rg -q '\$\{MIND_PALACE_PORT:-2080\}:2080' "$compose"
rg -q '^volumes:' "$compose"

published_count="$(rg -n '^[[:space:]]+ports:' "$compose" | wc -l)"
if [ "$published_count" -ne 1 ]; then
  echo "expected exactly one published service, found $published_count" >&2
  exit 1
fi

echo "packaged compose contract ok"
