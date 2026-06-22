# Contracts: Settings Page

No new API contracts. This feature is purely client-side.

- **Theme persistence**: `shared_preferences` key `theme_mode` with string values `"light"`, `"dark"`, `"system"`.
- **Password reset**: Uses existing Authentik OIDC flow at `${AUTHENTIK_URL}/if/flow/password-reset/`.
