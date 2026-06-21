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

Browser code must use the public origin, not Docker-internal service names.

## Engram Auth Helper Contract

Engram API must expose the following routes:

### `GET /api/auth/config`

Returns client-consumable auth capabilities.

Required response fields:

```json
{
  "oidc": {
    "enabled": true,
    "issuer_url": "http://localhost:2080/application/o/mind-palace/",
    "client_id": "mind-palace",
    "username_claim": "preferred_username",
    "redirect_uri": "http://localhost:2080/callback"
  },
  "none": {
    "enabled": false
  }
}
```

When OIDC is disabled, `oidc.enabled` must be `false`; secrets must not be
included.

### `GET /api/auth/oidc/discovery`

Fetches and returns the configured provider discovery document. It must fail
with a clear non-2xx response when OIDC is disabled or `OIDC_ISSUER_URL` is
missing.

### `POST /api/auth/oidc/token`

Proxies OAuth token requests to the configured provider. Supported grant types:

- `authorization_code`
- `refresh_token`

The endpoint must accept JSON request bodies and return the provider token
response plus a best-effort `username` field when userinfo lookup succeeds. It
must not expose client secrets.

## Client Platform Contract

The Mind Palace Flutter app must support:

- Linux desktop: existing loopback/AppAuth flow remains available.
- Web: browser redirect to IdP, same-origin `/callback` redirect URI, PKCE
  state/verifier storage, token exchange through Engram helper endpoint.

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
- `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/engram/health`
- `curl --fail http://localhost:${MIND_PALACE_PORT:-2080}/api/engram/auth/config`
  or the final documented auth config route

