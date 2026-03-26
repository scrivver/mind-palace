{ pkgs }:
let
  secretKey = "mind-palace-dev-secret-key-change-in-prod";
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

    authentik-redis = {
      command = pkgs.writeShellScript "start-authentik-redis" ''
        set -euo pipefail

        REDIS_DIR="$DATA_DIR/authentik/redis"
        mkdir -p "$REDIS_DIR"

        REDIS_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
        echo "$REDIS_PORT" > "$DATA_DIR/authentik/redis_port"

        echo "Redis starting on :$REDIS_PORT"

        exec ${pkgs.redis}/bin/redis-server \
          --bind 127.0.0.1 \
          --port "$REDIS_PORT" \
          --dir "$REDIS_DIR" \
          --dbfilename "authentik.rdb" \
          --save 60 1
      '';
      readiness_probe = {
        exec.command = pkgs.writeShellScript "authentik-redis-ready" ''
          REDIS_PORT=$(cat "$DATA_DIR/authentik/redis_port" 2>/dev/null) || exit 1
          ${pkgs.redis}/bin/redis-cli -h 127.0.0.1 -p "$REDIS_PORT" ping | grep -q PONG
        '';
        initial_delay_seconds = 2;
        period_seconds = 2;
      };
    };

    authentik-migrate = {
      command = pkgs.writeShellScript "authentik-migrate" ''
        set -euo pipefail

        PG_SOCKET_DIR=$(cat "$DATA_DIR/authentik/pg_socket_dir")
        REDIS_PORT=$(cat "$DATA_DIR/authentik/redis_port")

        export AUTHENTIK_SECRET_KEY="${secretKey}"
        export AUTHENTIK_POSTGRESQL__HOST="$PG_SOCKET_DIR"
        export AUTHENTIK_POSTGRESQL__NAME="authentik"
        export AUTHENTIK_POSTGRESQL__USER="authentik"
        export AUTHENTIK_POSTGRESQL__PASSWORD="authentik"
        export AUTHENTIK_REDIS__HOST="127.0.0.1"
        export AUTHENTIK_REDIS__PORT="$REDIS_PORT"

        echo "Running authentik migrations..."
        ${pkgs.authentik}/bin/ak migrate

        echo "Authentik migrations complete"
      '';
      depends_on = {
        authentik-db.condition = "process_healthy";
        authentik-redis.condition = "process_healthy";
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
        REDIS_PORT=$(cat "$DATA_DIR/authentik/redis_port")

        AK_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
        echo "$AK_PORT" > "$DATA_DIR/authentik/server_port"

        export AUTHENTIK_SECRET_KEY="${secretKey}"
        export AUTHENTIK_POSTGRESQL__HOST="$PG_SOCKET_DIR"
        export AUTHENTIK_POSTGRESQL__NAME="authentik"
        export AUTHENTIK_POSTGRESQL__USER="authentik"
        export AUTHENTIK_POSTGRESQL__PASSWORD="authentik"
        export AUTHENTIK_REDIS__HOST="127.0.0.1"
        export AUTHENTIK_REDIS__PORT="$REDIS_PORT"
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
          curl -sf "http://127.0.0.1:$AK_PORT/-/health/live/" -o /dev/null 2>&1
        '';
        initial_delay_seconds = 10;
        period_seconds = 5;
      };
    };

    authentik-worker = {
      command = pkgs.writeShellScript "start-authentik-worker" ''
        set -euo pipefail

        PG_SOCKET_DIR=$(cat "$DATA_DIR/authentik/pg_socket_dir")
        REDIS_PORT=$(cat "$DATA_DIR/authentik/redis_port")

        export AUTHENTIK_SECRET_KEY="${secretKey}"
        export AUTHENTIK_POSTGRESQL__HOST="$PG_SOCKET_DIR"
        export AUTHENTIK_POSTGRESQL__NAME="authentik"
        export AUTHENTIK_POSTGRESQL__USER="authentik"
        export AUTHENTIK_POSTGRESQL__PASSWORD="authentik"
        export AUTHENTIK_REDIS__HOST="127.0.0.1"
        export AUTHENTIK_REDIS__PORT="$REDIS_PORT"

        echo "Authentik worker starting..."

        exec ${pkgs.authentik}/bin/ak worker
      '';
      depends_on = {
        authentik-migrate.condition = "process_completed";
      };
    };
  };
}
