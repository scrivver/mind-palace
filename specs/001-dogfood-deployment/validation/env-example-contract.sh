#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/../../.." && pwd)"
env_file="$root/.env.example"

required_vars=(
  MIND_PALACE_PORT
  PROXY_BASE_URL
  POSTGRES_PASSWORD
  RABBITMQ_DEFAULT_USER
  RABBITMQ_DEFAULT_PASS
  MINIO_ROOT_USER
  MINIO_ROOT_PASSWORD
  AUTHENTIK_SECRET_KEY
  AUTH_PASSWORD
  JWT_SECRET
  EVENT_QUEUE
  S3_HOT_BUCKET
  S3_COLD_BUCKET
)

test -f "$env_file"
for var in "${required_vars[@]}"; do
  rg -q "^${var}=" "$env_file" || {
    echo "missing env var: $var" >&2
    exit 1
  }
done

for secret in POSTGRES_PASSWORD MINIO_ROOT_PASSWORD AUTHENTIK_SECRET_KEY AUTH_PASSWORD JWT_SECRET; do
  rg -q "^${secret}=change-me-in-shared-use" "$env_file" || {
    echo "secret placeholder not obvious for $secret" >&2
    exit 1
  }
done

echo "env example contract ok"
