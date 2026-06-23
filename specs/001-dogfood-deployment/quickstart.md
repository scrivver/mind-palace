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
    curl --fail "http://127.0.0.1:$PROXY_PORT/api/reliquary/api/health"
    curl --fail "http://127.0.0.1:$PROXY_PORT/api/engram/api/health"
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

1. Confirm child repositories expose packaged image targets:

   ```bash
   nix eval --json path:./engram#packages.x86_64-linux --apply 'builtins.attrNames'
   nix eval --json path:./synapse#packages.x86_64-linux --apply 'builtins.attrNames'
   ```

   Expected result: Engram exposes `api-container` and `ingestion-container`.
   Synapse exposes `worker-container` and `reconciler-container`. These
   child-owned output names are documented in the child repos and consumed by
   root `bin/deploy`.

2. Confirm root-owned packaged image targets are present:

   ```bash
   nix eval --json .#packages.x86_64-linux --apply 'builtins.attrNames'
   ```

   Expected result: the output includes a real `mind-palace-app-container`
   target for the Flutter web UI, a `mind-palace-app-web` target for the static
   web bundle, the root ingress target if retained, and any intentionally thin
   aliases. Engram and Synapse implementation packaging must not appear as
   root-owned placeholder container targets.

3. Build the primary app web image directly during implementation validation:

   ```bash
   nix build .#mind-palace-app-container --no-link --print-out-paths
   ```

   Expected result: the command prints a loadable image archive path for a Caddy
   image serving the Nix-built Flutter web app. The image must not be a
   placeholder sleep container.

4. Build the new Engram and Synapse images directly during implementation
   validation:

   ```bash
   nix build path:./engram#api-container --no-link --print-out-paths
   nix build path:./engram#ingestion-container --no-link --print-out-paths
   nix build path:./synapse#worker-container --no-link --print-out-paths
   nix build path:./synapse#reconciler-container --no-link --print-out-paths
   ```

   Expected result: each command prints a loadable image archive path. These
   child-owned targets must run real component entrypoints, not placeholder
   sleep commands.

5. Build and load all local images through the platform deployment command:

   ```bash
   nix develop
   ./bin/deploy
   ```

   Expected result: all images referenced by `docker-compose.yml` are loaded
   into Docker or Podman. Root `bin/deploy` builds child-repo image outputs,
   loads them, and tags them to the `mind-palace-*` names expected by Compose.

6. Confirm loaded image names:

   ```bash
   docker image ls \
     mind-palace-app \
     mind-palace-engram-api \
     mind-palace-engram-ingestion \
     mind-palace-synapse-worker \
     mind-palace-synapse-reconciler
   ```

   Use the matching Podman image command when Podman is selected.

   Expected result: all listed images exist with the `latest` tag.

7. Prepare configuration:

   ```bash
   cp .env.example .env
   ```

   Edit `.env` and replace documented placeholder secrets before shared use.

8. Validate Compose configuration before startup:

   ```bash
   docker compose config --quiet
   ```

9. Start packaged deployment:

   ```bash
   docker compose up -d
   ```

   Use `podman compose up -d` if Podman is the selected runtime.

10. Check status and health:

   ```bash
   docker compose ps
   curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/health
   curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/
    curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/engram/api/health
   ```

   Expected result: only the public entry point is exposed by default, the
   browser UI route returns the Flutter web shell, and service health is visible
   through Compose.

11. Validate Reliquary auth discovery:

    ```bash
    curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/reliquary/api/auth/config
    ```

    Expected result: the config endpoint returns no secrets and identifies
    whether password auth and/or OIDC is enabled. When OIDC is enabled, the
    returned `issuer_url` and `client_id` are used for direct OIDC discovery.
    A browser sign-in redirect must return to `/callback`, which serves the same
    Flutter shell as `/`.

12. Run the same smoke workflow used for local dogfood:

   - Open the packaged public entry point.
    - Authenticate with the default admin credentials from `.env` or use the
      documented packaged OIDC mode.
   - Add a small artifact through the web upload flow.
   - Confirm metadata discovery.
   - Confirm movement/reconciliation behavior when enabled.
   - If behavior differs from local development, classify the failure as child
     packaging, root image tagging/loading, Compose wiring, web compile, Caddy
     proxy, OIDC helper, browser callback, runtime startup, or smoke-test
     workflow before filing the report.

13. Inspect logs on failure:

   ```bash
   docker compose logs --tail=200
   ```

   Sanitize secrets before copying logs into a failure report.

14. Stop packaged deployment:

   ```bash
   docker compose down
   ```

15. Reset packaged state only when intended:

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
- Failure category: child packaging, root image tagging/loading, Compose
  wiring, web compile, Caddy proxy, auth discovery, browser callback, runtime
  startup, or smoke test.
