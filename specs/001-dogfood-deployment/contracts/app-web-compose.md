# Contract: Mind Palace Web App Compose Runtime

## Scope

The packaged dogfood deployment must expose a usable Mind Palace web UI through
the default Compose public entry point. The web UI is the browser-accessible
equivalent of the local Flutter desktop app for smoke testing storage,
metadata, and reconciliation workflows.

## Required Files

- `app/web/index.html`: Flutter web host page.
- `app/pubspec.lock.json`: JSON lock data consumed by the Nix Flutter web build.
- `nix/app-web.nix`: builds the Flutter web artifact from `app/`.
- `nix/app-web-container.nix`: serves the web artifact with Caddy.
- `docker-compose.yml`: runs `mind-palace-app:latest` as the public web UI or
  as the app service behind the public ingress.
- `bin/deploy`: builds and loads the root app web image before Compose startup.

## Image Contract

The root app image must be:

- Image name: `mind-palace-app:latest`
- Owner: Mind Palace root repository
- Build target: `mind-palace-app-container`
- Runtime: Caddy serving static Flutter web files
- Public port inside container: `2080/tcp` unless a separate ingress keeps the
  public port and proxies to the app container
- Healthcheck: verifies the web shell and at least one proxied API health route

The image must not:

- run `flutter run` or a development server at Compose startup
- require source bind mounts
- serve only a placeholder response
- bake secret values into the static bundle

## Web Routing Contract

The public browser origin must support:

- `GET /` and `GET /index.html`: serve the Flutter web app
- `GET /callback`: serve the Flutter web app so web OIDC redirect completion can
  run client-side
- `GET /health`: return a public health response
- `/api/reliquary/*`: reverse proxy to Reliquary API with the prefix stripped or
  mapped so existing Reliquary routes receive `/api/...`
- `/api/engram/*`: reverse proxy to Engram API with the prefix stripped or
  mapped so existing Engram routes receive `/api/...`
- `/storage/*`: reverse proxy to MinIO with the prefix stripped so presigned
  object URLs resolve

Browser code must use the public origin, not Docker-internal service names.

## Auth Discovery Contract

Reliquary API must expose `GET /api/auth/config` returning client-consumable
auth capabilities. Example response in password mode:

```json
{
  "password": {
    "enabled": true
  },
  "oidc": {
    "enabled": false,
    "issuer_url": "",
    "client_id": "",
    "username_claim": "preferred_username",
    "redirect_uri": "com.reliquary.app://callback"
  },
  "proxy": {
    "enabled": false,
    "legacy": true
  },
  "none": {
    "enabled": false
  }
}
```

When OIDC is enabled, `oidc.enabled` is `true` and `issuer_url`/`client_id` are
populated so the Flutter app can perform direct OIDC discovery. Secrets must not
be included.

## Client Platform Contract

The Mind Palace Flutter app must support:

- Linux desktop: existing loopback/AppAuth flow remains available.
- Web: browser redirect to IdP, same-origin `/callback` redirect URI, PKCE
  state/verifier storage, token exchange directly with the OIDC provider when
  OIDC mode is enabled, or username/password login through Reliquary when
  password mode is enabled.

Web builds must not import `dart:io` in any compilation unit selected for web.

## Validation Contract

Validation must cover:

- `cd app && flutter analyze`
- `cd app && flutter test`
- app web build through Nix or `flutter build web`
- `nix build .#mind-palace-app-container --no-link --print-out-paths`
- `./bin/deploy`
- `docker compose config --quiet`
- `docker compose up -d`
- `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/`
- `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/engram/api/health`
- `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/reliquary/api/auth/config`

