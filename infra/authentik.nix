{ pkgs }:
let
  secretKey = "mind-palace-dev-secret-key-change-in-prod";
  bootstrapPassword = "mind-palace-admin";
  bootstrapToken = "mind-palace-dev-token";

  # Python script to provision OAuth2 provider + application via the API
  oauth2SetupPy = pkgs.writeText "authentik-oauth2-setup.py" ''
    import os, sys, json, time, urllib.request, urllib.error

    ak_port = open(os.path.join(os.environ["DATA_DIR"], "authentik/server_port")).read().strip()
    api = f"http://127.0.0.1:{ak_port}/api/v3"
    token = "${bootstrapToken}"

    def api_call(method, path, data=None):
        url = f"{api}{path}"
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        body = json.dumps(data).encode() if data else None
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            print(f"API error {e.code}: {e.read().decode()}", file=sys.stderr)
            raise

    def wait_for_flow(slugs, label, max_wait=120):
        """Wait for any of the given flow slugs to become available."""
        for attempt in range(max_wait // 5):
            for slug in slugs:
                flows = api_call("GET", f"/flows/instances/?slug={slug}")
                if flows["results"]:
                    return flows["results"][0]["pk"]
            if attempt == 0:
                print(f"Waiting for {label} (blueprints still loading)...")
            time.sleep(5)
        print(f"ERROR: {label} not found after {max_wait}s", file=sys.stderr)
        sys.exit(1)

    # Check if application already exists
    apps = api_call("GET", "/core/applications/?slug=mind-palace")
    if apps["pagination"]["count"] > 0:
        print("Mind Palace OAuth2 application already exists, skipping setup")
        sys.exit(0)

    print("Setting up Mind Palace OAuth2 provider...")

    # Wait for flows to be created by blueprints (applied async by worker)
    auth_flow = wait_for_flow(
        ["default-provider-authorization-implicit-consent", "default-provider-authorization-explicit-consent"],
        "authorization flow",
    )
    invalidation_flow = wait_for_flow(
        ["default-provider-invalidation-flow", "default-invalidation-flow"],
        "invalidation flow",
    )

    # Get default scope mappings
    scopes = api_call("GET", "/propertymappings/provider/scope/?ordering=scope_name")
    scope_pks = [s["pk"] for s in scopes["results"] if s["scope_name"] in ("openid", "email", "profile")]

    # Create OAuth2 provider
    provider = api_call("POST", "/providers/oauth2/", {
        "name": "Mind Palace OAuth2",
        "authorization_flow": auth_flow,
        "invalidation_flow": invalidation_flow,
        "client_type": "public",
        "client_id": "mind-palace",
        "redirect_uris": [
            {"matching_mode": "regex", "url": "http://localhost:.*/callback"},
            {"matching_mode": "regex", "url": "http://127.0.0.1:.*/callback"},
        ],
        "property_mappings": scope_pks,
    })
    print(f"  Created OAuth2 provider (pk={provider['pk']})")

    # Create application
    api_call("POST", "/core/applications/", {
        "name": "Mind Palace",
        "slug": "mind-palace",
        "provider": provider["pk"],
        "meta_launch_url": "http://localhost:8080",
    })

    print("  Created Mind Palace application")
    print("OAuth2 setup complete")
    print(f"  Client ID: mind-palace")
    print(f"  OIDC Discovery: http://127.0.0.1:{ak_port}/application/o/mind-palace/.well-known/openid-configuration")
  '';

  oauth2Setup = pkgs.writeShellScript "authentik-oauth2-setup" ''
    set -euo pipefail

    PG_SOCKET_DIR=$(cat "$DATA_DIR/authentik/pg_socket_dir")

    # Ensure the API token exists in the database (idempotent)
    ${pkgs.postgresql}/bin/psql -h "$PG_SOCKET_DIR" -U authentik -d authentik -c "
      INSERT INTO authentik_core_token (
        identifier, key, intent, expiring, managed,
        description, user_id, token_uuid
      )
      SELECT
        'mind-palace-api',
        '${bootstrapToken}',
        'api',
        false,
        'goauthentik.io/token/mind-palace-api',
        'Auto-created dev token for OAuth2 setup',
        u.id,
        gen_random_uuid()
      FROM authentik_core_user u
      WHERE u.username = 'akadmin'
      ON CONFLICT (identifier) DO UPDATE SET key = '${bootstrapToken}';
    "

    exec ${pkgs.python3}/bin/python3 ${oauth2SetupPy}
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

        # Ensure akadmin user exists with correct password (idempotent)
        ${pkgs.authentik}/bin/ak shell -c "
from authentik.core.models import User, UserTypes
user, created = User.objects.get_or_create(
    username='akadmin',
    defaults={
        'email': 'admin@mind-palace.local',
        'name': 'akadmin',
        'type': UserTypes.INTERNAL_SERVICE_ACCOUNT,
    }
)
user.set_password('${bootstrapPassword}')
user.save()
if created:
    print('Created akadmin user')
else:
    print('Reset akadmin password')
"

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

    authentik-oauth2-setup = {
      command = oauth2Setup;
      depends_on = {
        authentik-server.condition = "process_healthy";
      };
      availability = {
        restart = "no";
      };
    };
  };
}
