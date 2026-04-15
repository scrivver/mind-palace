{ pkgs, databases ? [ "authentik" "engram" "synapse" ] }:
let
  createDbCommands = builtins.concatStringsSep "\n" (map (db: ''
    if ! psql -h "$DATA_DIR/postgres" -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${db}'" | grep -q 1; then
      echo "Creating database '${db}'..."
      createdb -h "$DATA_DIR/postgres" "${db}"
      if [ "${db}" = "authentik" ]; then
        psql -h "$DATA_DIR/postgres" -d postgres -c "CREATE USER authentik WITH PASSWORD 'authentik';" || true
        psql -h "$DATA_DIR/postgres" -d postgres -c "ALTER DATABASE authentik OWNER authentik;" || true
      fi
    else
      echo "Database '${db}' already exists."
    fi
  '') databases);
in
{
  processes = {
    postgres = {
      command = pkgs.writeShellScript "start-postgres" ''
        set -euo pipefail
        PGDATA="$DATA_DIR/postgres"

        if [ ! -f "$PGDATA/PG_VERSION" ]; then
          echo "Initializing PostgreSQL database..."
          initdb -D "$PGDATA" --no-locale --encoding=UTF8
          cat >> "$PGDATA/postgresql.conf" <<CONF
        unix_socket_directories = '$PGDATA'
        listen_addresses = '''
        CONF
        fi

        exec postgres -D "$PGDATA" -k "$PGDATA"
      '';
      readiness_probe = {
        exec.command = pkgs.writeShellScript "pg-ready" ''
          pg_isready -h "$DATA_DIR/postgres" -d postgres
        '';
        initial_delay_seconds = 2;
        period_seconds = 2;
      };
    };

    postgres-init = {
      command = pkgs.writeShellScript "init-databases" ''
        set -euo pipefail
        ${createDbCommands}
        echo "All databases ensured."
      '';
      depends_on.postgres.condition = "process_healthy";
      availability.restart = "no";
    };
  };

  socketDir = "$DATA_DIR/postgres";
}
