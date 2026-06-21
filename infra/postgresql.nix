{ pkgs, databases ? [ "authentik" "engram" "synapse" ] }:
let
  psqlCmd = "psql -h \"$DATA_DIR/postgres\" -U postgres";
  createDbCommands = builtins.concatStringsSep "\n" (map (db: ''
    if ! ${psqlCmd} -d postgres -tc "SELECT 1 FROM pg_database WHERE datname = '${db}'" | grep -q 1; then
      echo "Creating database '${db}'..."
      createdb -h "$DATA_DIR/postgres" -U postgres "${db}"
    fi

    if [ "${db}" = "authentik" ]; then
      echo "Configuring permissions for '${db}'..."
      # Ensure user exists
      ${psqlCmd} -d postgres -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'authentik') THEN CREATE ROLE authentik WITH LOGIN PASSWORD 'authentik'; END IF; END \$\$;"
      # Grant database-level permissions
      ${psqlCmd} -d postgres -c "GRANT CONNECT ON DATABASE authentik TO authentik;"
      ${psqlCmd} -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE authentik TO authentik;"
      ${psqlCmd} -d postgres -c "ALTER DATABASE authentik OWNER TO authentik;"
      # Grant schema-level permissions
      ${psqlCmd} -d authentik -c "GRANT ALL ON SCHEMA public TO authentik;"
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

        # Ensure postgres superuser role exists (initdb creates a role matching the OS user, not postgres)
        psql -h "$DATA_DIR/postgres" -d postgres -tc "SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = 'postgres'" | grep -q 1 || \
          psql -h "$DATA_DIR/postgres" -d postgres -c "CREATE ROLE postgres WITH SUPERUSER LOGIN;"

        ${createDbCommands}
        echo "All databases ensured."
      '';
      depends_on.postgres.condition = "process_healthy";
      availability.restart = "no";
    };
  };

  socketDir = "$DATA_DIR/postgres";
}
