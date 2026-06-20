# Quickstart: Dogfood Deployment Validation

This guide validates the planned dogfood deployment feature after implementation.
It is not an implementation script.

## Prerequisites

- Nix with flakes enabled.
- Git submodules initialized: `git submodule update --init --recursive`.
- Docker or Podman with Compose support for packaged validation.
- A clean or intentionally reused `.data/` directory for local validation.

## Validate Local Dogfood Startup

1. Enter the root development shell:

   ```bash
   nix develop
   ```

2. Start the full local dogfood stack:

   ```bash
   dev
   ```

3. Confirm process status:

   ```bash
   process-compose process list -u "$PC_SOCKET"
   ```

   Expected result: required infrastructure, backend, worker, proxy, identity,
   and app services are running or healthy. `dev` must not instruct the user to
   run `start-infra` first.

4. Load generated environment values:

   ```bash
   source load-infra-env
   ```

5. Probe public routes:

   ```bash
   curl --fail "http://127.0.0.1:$PROXY_PORT/health"
   curl --fail "http://127.0.0.1:$PROXY_PORT/api/reliquary/health"
   curl --fail "http://127.0.0.1:$PROXY_PORT/api/engram/health"
   ```

   Expected result: health probes return success for available routes.

6. Run the dogfood smoke workflow:

   - Open the primary app entry point.
   - Authenticate or use the documented local access mode.
   - Add a small artifact.
   - Confirm the artifact appears in storage.
   - Confirm metadata becomes discoverable.
   - Trigger or verify movement/reconciliation behavior when enabled.

7. Stop the stack:

   ```bash
   shutdown-infra
   ```

   Expected result: managed processes stop and `.data/` remains available for
   reuse.

## Validate Packaged Compose Deployment

1. Build and load local images:

   ```bash
   nix develop
   ./bin/deploy
   ```

   Expected result: all images referenced by `docker-compose.yml` are loaded
   into Docker or Podman.

2. Prepare configuration:

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and replace documented placeholder secrets before shared use.

3. Start packaged deployment:

   ```bash
   docker compose up -d
   ```

   Use `podman compose up -d` if Podman is the selected runtime.

4. Check status and health:

   ```bash
   docker compose ps
   curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/health
   ```

   Expected result: only the public entry point is exposed by default and
   service health is visible through Compose.

5. Run the same smoke workflow used for local dogfood:

   - Open the packaged public entry point.
   - Authenticate or use the documented packaged access mode.
   - Add a small artifact.
   - Confirm metadata discovery.
   - Confirm movement/reconciliation behavior when enabled.

6. Inspect logs on failure:

   ```bash
   docker compose logs --tail=200
   ```

   Sanitize secrets before copying logs into a failure report.

7. Stop packaged deployment:

   ```bash
   docker compose down
   ```

8. Reset packaged state only when intended:

   ```bash
   docker compose down -v
   ```

   Expected result: named volumes are removed only after explicit reset.

## Failure Report Checklist

Include the following in dogfood reports:

- Deployment path: `local-dev` or `packaged-compose`.
- Whether state was fresh, reused, migrated, or unknown.
- Service status snapshot.
- Failed service name, if known.
- Sanitized log excerpt.
- Configuration source, without secret values.
- Exact smoke-test step that failed.
