{ pkgs }:
let
  secretKey = "mind-palace-dev-secret-key-change-in-prod";
  adminPassword = "mind-palace-admin";

  # Single Python script that bootstraps everything via HTTP APIs:
  # 1. Completes initial-setup flow to create akadmin user
  # 2. Logs in and creates an API token
  # 3. Waits for default flows (applied by worker)
  # 4. Creates OAuth2 provider + application
  setupPy = pkgs.writeText "authentik-setup.py" ''
    import os, sys, json, time, urllib.request, urllib.error, http.cookiejar

    ak_port = open(os.path.join(os.environ["DATA_DIR"], "authentik/server_port")).read().strip()
    base = f"http://127.0.0.1:{ak_port}"
    api = f"{base}/api/v3"
    password = "${adminPassword}"

    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))

    def get_csrf_token():
        for cookie in cj:
            if cookie.name == "authentik_csrf":
                return cookie.value
        return None

    def http_call(method, url, data=None, headers=None):
        hdrs = {"Content-Type": "application/json"}
        # Add CSRF token for session-authenticated requests
        csrf = get_csrf_token()
        if csrf:
            hdrs["X-authentik-CSRF"] = csrf
        if headers:
            hdrs.update(headers)
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, headers=hdrs, method=method)
        try:
            with opener.open(req) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            body = e.read().decode()
            print(f"HTTP {e.code} on {method} {url}: {body}", file=sys.stderr)
            raise

    def api_call(method, path, data=None, token=None):
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"
        return http_call(method, f"{api}{path}", data, headers)

    # ── Step 1: Complete initial-setup flow to create akadmin ──
    print("Step 1: Checking if initial setup is needed...")
    try:
        resp = http_call("GET", f"{base}/api/v3/flows/executor/initial-setup/")
        component = resp.get("component", "")
        if component == "ak-stage-prompt":
            print("  Running initial setup flow...")
            # Submit the setup form with admin credentials
            http_call("POST", f"{base}/api/v3/flows/executor/initial-setup/", {
                "component": "ak-stage-prompt",
                "username": "akadmin",
                "password": password,
                "password_repeat": password,
                "email": "admin@mind-palace.local",
                "locale": "",
            })
            print("  Initial setup complete - akadmin user created")
        elif "xak-flow-redirect" in component or "redirect" in str(resp):
            print("  Initial setup already completed, skipping")
        else:
            print(f"  Unexpected flow state: {component}, skipping initial setup")
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print("  Initial setup flow not found (already completed)")
        else:
            raise

    # ── Step 2: Log in as akadmin and create API token ──
    print("Step 2: Authenticating as akadmin...")

    # Start the authentication flow
    auth_resp = http_call("GET", f"{base}/api/v3/flows/executor/default-authentication-flow/")

    # Wait for the authentication flow to be available (blueprints may still be loading)
    for attempt in range(60):
        try:
            auth_resp = http_call("GET", f"{base}/api/v3/flows/executor/default-authentication-flow/")
            if auth_resp.get("component"):
                break
        except urllib.error.HTTPError:
            pass
        if attempt == 0:
            print("  Waiting for authentication flow...")
        time.sleep(3)

    # Submit identification stage
    http_call("POST", f"{base}/api/v3/flows/executor/default-authentication-flow/", {
        "component": "ak-stage-identification",
        "uid_field": "akadmin",
    })

    # Submit password stage
    auth_result = http_call("POST", f"{base}/api/v3/flows/executor/default-authentication-flow/", {
        "component": "ak-stage-password",
        "password": password,
    })

    # We should now have a session cookie
    print("  Logged in as akadmin")

    # Create API token via session auth
    print("  Creating API token...")
    try:
        token_resp = api_call("POST", "/core/tokens/", {
            "identifier": "mind-palace-api",
            "intent": "api",
            "expiring": False,
            "description": "Mind Palace dev API token",
        })
        # Retrieve the actual key
        token_key_resp = api_call("GET", f"/core/tokens/mind-palace-api/view_key/")
        token = token_key_resp["key"]
        print(f"  API token created")
    except urllib.error.HTTPError as e:
        if e.code == 400 and "already exists" in str(e.read() if hasattr(e, 'read') else ""):
            # Token already exists, retrieve key
            token_key_resp = api_call("GET", "/core/tokens/mind-palace-api/view_key/")
            token = token_key_resp["key"]
            print(f"  API token already exists, retrieved key")
        else:
            raise

    # ── Step 3: Check if OAuth2 app already exists ──
    apps = api_call("GET", "/core/applications/?slug=mind-palace", token=token)
    if apps["pagination"]["count"] > 0:
        print("Mind Palace OAuth2 application already exists, skipping")
        sys.exit(0)

    # ── Step 4: Wait for default flows and create OAuth2 provider ──
    print("Step 3: Setting up OAuth2 provider...")

    def wait_for(path, label, key="results", max_wait=180):
        for attempt in range(max_wait // 5):
            resp = api_call("GET", path, token=token)
            if resp.get(key):
                return resp[key]
            if attempt == 0:
                print(f"  Waiting for {label}...")
            time.sleep(5)
        print(f"  ERROR: {label} not available after {max_wait}s", file=sys.stderr)
        sys.exit(1)

    # Wait for authorization flow
    auth_flows = wait_for(
        "/flows/instances/?slug=default-provider-authorization-implicit-consent",
        "authorization flow",
    )
    auth_flow_pk = auth_flows[0]["pk"]

    # Wait for invalidation flow
    inv_flows = wait_for(
        "/flows/instances/?slug=default-provider-invalidation-flow",
        "invalidation flow",
    )
    inv_flow_pk = inv_flows[0]["pk"]

    # Get scope mappings
    scopes = api_call("GET", "/propertymappings/provider/scope/?ordering=scope_name", token=token)
    scope_pks = [s["pk"] for s in scopes["results"] if s["scope_name"] in ("openid", "email", "profile")]

    # Create OAuth2 provider
    provider = api_call("POST", "/providers/oauth2/", {
        "name": "Mind Palace OAuth2",
        "authorization_flow": auth_flow_pk,
        "invalidation_flow": inv_flow_pk,
        "client_type": "public",
        "client_id": "mind-palace",
        "redirect_uris": [
            {"matching_mode": "regex", "url": "http://localhost:.*/callback"},
            {"matching_mode": "regex", "url": "http://127.0.0.1:.*/callback"},
            {"matching_mode": "regex", "url": "com\\.mindpalace\\.app://callback"},
        ],
        "property_mappings": scope_pks,
    }, token=token)
    print(f"  Created OAuth2 provider (pk={provider['pk']})")

    # Create application
    api_call("POST", "/core/applications/", {
        "name": "Mind Palace",
        "slug": "mind-palace",
        "provider": provider["pk"],
        "meta_launch_url": "http://localhost:8080",
    }, token=token)

    print("  Created Mind Palace application")
    print("")
    print("Setup complete!")
    print(f"  Admin:          akadmin / ${adminPassword}")
    print(f"  Admin UI:       http://127.0.0.1:{ak_port}/if/admin/")
    print(f"  Client ID:      mind-palace")
    print(f"  OIDC Discovery: http://127.0.0.1:{ak_port}/application/o/mind-palace/.well-known/openid-configuration")
  '';

  setupScript = pkgs.writeShellScript "authentik-setup" ''
    exec ${pkgs.python3}/bin/python3 ${setupPy}
  '';
in
{
  processes = {
    authentik-db = {
      command = pkgs.writeShellScript "start-authentik-db" ''
        set -euo pipefail

        PG_DIR="$DATA_DIR/authentik/postgres"
        mkdir -p "$PG_DIR/data" "$PG_DIR/run"

        # Write the socket dir path so other processes can find it
        echo "$PG_DIR/run" > "$DATA_DIR/authentik/pg_socket_dir"

        # Initialize database if needed
        if [ ! -f "$PG_DIR/data/PG_VERSION" ]; then
          ${pkgs.postgresql}/bin/initdb -D "$PG_DIR/data" --no-locale --encoding=UTF8
          # Listen only on unix socket, no TCP
          cat >> "$PG_DIR/data/postgresql.conf" <<PGEOF
        listen_addresses = '''
        unix_socket_directories = '$PG_DIR/run'
        PGEOF
        fi

        # Allow any local user to connect via unix socket (dev only)
        cat > "$PG_DIR/data/pg_hba.conf" <<HBAEOF
        local   all   all   trust
        host    all   all   127.0.0.1/32   trust
        HBAEOF

        echo "PostgreSQL starting (unix socket: $PG_DIR/run)"

        # Start temporarily in background to run setup SQL
        ${pkgs.postgresql}/bin/pg_ctl -D "$PG_DIR/data" -l "$PG_DIR/pg.log" start

        # The superuser is the current OS user (from initdb).
        # Create the authentik role and database if they don't exist.
        ${pkgs.postgresql}/bin/psql -h "$PG_DIR/run" -d postgres -tc \
          "SELECT 1 FROM pg_roles WHERE rolname='authentik'" | grep -q 1 || \
          ${pkgs.postgresql}/bin/psql -h "$PG_DIR/run" -d postgres -c \
          "CREATE USER authentik WITH PASSWORD 'authentik';"

        ${pkgs.postgresql}/bin/psql -h "$PG_DIR/run" -d postgres -tc \
          "SELECT 1 FROM pg_database WHERE datname='authentik'" | grep -q 1 || \
          ${pkgs.postgresql}/bin/psql -h "$PG_DIR/run" -d postgres -c \
          "CREATE DATABASE authentik OWNER authentik;"

        echo "PostgreSQL setup complete, restarting in foreground"

        # Stop the background instance, then run postgres in foreground
        # so process-compose signals go directly to the postgres process
        ${pkgs.postgresql}/bin/pg_ctl -D "$PG_DIR/data" stop -m fast

        exec ${pkgs.postgresql}/bin/postgres -D "$PG_DIR/data" -k "$PG_DIR/run"
      '';
      readiness_probe = {
        exec.command = pkgs.writeShellScript "authentik-db-ready" ''
          PG_DIR="$DATA_DIR/authentik/postgres"
          ${pkgs.postgresql}/bin/pg_isready -h "$PG_DIR/run" -d postgres -q
        '';
        initial_delay_seconds = 3;
        period_seconds = 2;
      };
      # postgres runs in foreground — SIGTERM (default) triggers clean shutdown
    };

    authentik-migrate = {
      command = pkgs.writeShellScript "authentik-migrate" ''
        set -euo pipefail

        PG_SOCKET_DIR=$(cat "$DATA_DIR/authentik/pg_socket_dir")

        export AUTHENTIK_SECRET_KEY="${secretKey}"
        export AUTHENTIK_POSTGRESQL__HOST="$PG_SOCKET_DIR"
        export AUTHENTIK_POSTGRESQL__NAME="authentik"
        export AUTHENTIK_POSTGRESQL__USER="authentik"
        export AUTHENTIK_POSTGRESQL__PASSWORD="authentik"

        echo "Running authentik migrations..."
        ${pkgs.authentik}/bin/ak migrate

        echo "Authentik migrations complete"
      '';
      depends_on = {
        authentik-db.condition = "process_healthy";
      };
      availability = {
        restart = "no";
      };
    };

    authentik-server = {
      command = pkgs.writeShellScript "start-authentik-server" ''
        set -euo pipefail

        mkdir -p "$DATA_DIR/authentik"

        PG_SOCKET_DIR=$(cat "$DATA_DIR/authentik/pg_socket_dir")

        AK_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
        echo "$AK_PORT" > "$DATA_DIR/authentik/server_port"

        export AUTHENTIK_SECRET_KEY="${secretKey}"
        export AUTHENTIK_POSTGRESQL__HOST="$PG_SOCKET_DIR"
        export AUTHENTIK_POSTGRESQL__NAME="authentik"
        export AUTHENTIK_POSTGRESQL__USER="authentik"
        export AUTHENTIK_POSTGRESQL__PASSWORD="authentik"
        export AUTHENTIK_LISTEN__HTTP="0.0.0.0:$AK_PORT"

        echo "Authentik server starting on :$AK_PORT"

        exec ${pkgs.authentik}/bin/ak server
      '';
      depends_on = {
        authentik-migrate.condition = "process_completed";
      };
      readiness_probe = {
        exec.command = pkgs.writeShellScript "authentik-server-ready" ''
          AK_PORT=$(cat "$DATA_DIR/authentik/server_port" 2>/dev/null) || exit 1
          curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$AK_PORT/-/health/live/" | grep -q "200\|204"
        '';
        initial_delay_seconds = 30;
        period_seconds = 10;
        failure_threshold = 20;
      };
    };

    authentik-worker = {
      command = pkgs.writeShellScript "start-authentik-worker" ''
        set -euo pipefail

        PG_SOCKET_DIR=$(cat "$DATA_DIR/authentik/pg_socket_dir")

        export AUTHENTIK_SECRET_KEY="${secretKey}"
        export AUTHENTIK_POSTGRESQL__HOST="$PG_SOCKET_DIR"
        export AUTHENTIK_POSTGRESQL__NAME="authentik"
        export AUTHENTIK_POSTGRESQL__USER="authentik"
        export AUTHENTIK_POSTGRESQL__PASSWORD="authentik"

        echo "Authentik worker starting..."

        exec ${pkgs.authentik}/bin/ak worker
      '';
      depends_on = {
        authentik-migrate.condition = "process_completed";
      };
    };

    authentik-setup = {
      command = setupScript;
      depends_on = {
        authentik-server.condition = "process_healthy";
        authentik-worker.condition = "process_started";
      };
      availability = {
        restart = "no";
      };
    };
  };
}
