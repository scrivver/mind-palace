{ pkgs, buckets ? [ "reliquary" "engram" "synapse-vault" ] }:
{
  processes = {
    minio = {
      command = pkgs.writeShellScript "start-minio" ''
        set -euo pipefail

        MINIO_DIR="$DATA_DIR/minio"
        mkdir -p "$MINIO_DIR/data"
        rm -f "$MINIO_DIR/api_port" "$MINIO_DIR/console_port"

        API_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
        CONSOLE_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
        echo "$API_PORT" > "$MINIO_DIR/api_port"
        echo "$CONSOLE_PORT" > "$MINIO_DIR/console_port"

        export MINIO_ROOT_USER=minioadmin
        export MINIO_ROOT_PASSWORD=minioadmin

        echo "MinIO starting on API :$API_PORT, Console :$CONSOLE_PORT"

        exec ${pkgs.minio}/bin/minio server \
          --address "127.0.0.1:$API_PORT" \
          --console-address "127.0.0.1:$CONSOLE_PORT" \
          "$MINIO_DIR/data"
      '';
      readiness_probe = {
        exec.command = pkgs.writeShellScript "minio-ready" ''
          API_PORT=$(cat "$DATA_DIR/minio/api_port" 2>/dev/null) || exit 1
          curl -sf "http://127.0.0.1:$API_PORT/minio/health/live" -o /dev/null 2>&1
        '';
        initial_delay_seconds = 3;
        period_seconds = 2;
      };
    };

    minio-setup = {
      command = pkgs.writeShellScript "minio-setup" ''
        set -euo pipefail

        API_PORT=$(cat "$DATA_DIR/minio/api_port")
        ENDPOINT="http://127.0.0.1:$API_PORT"

        ${pkgs.minio-client}/bin/mc alias set local "$ENDPOINT" minioadmin minioadmin --api S3v4

        ${pkgs.lib.concatStringsSep "\n" (map (bucket: ''
          echo "Setting up bucket: ${bucket}"
          ${pkgs.minio-client}/bin/mc mb --ignore-existing local/${bucket}

          if [ "${bucket}" = "reliquary" ]; then
            # Reliquary publishes canonical events itself. Remove the legacy
            # bucket rule if this data directory predates explicit publication.
            ${pkgs.minio-client}/bin/mc event remove local/${bucket} --force 2>/dev/null || true
            echo "  Legacy bucket notifications disabled for ${bucket}"
          else
            ${pkgs.minio-client}/bin/mc anonymous set download local/${bucket}
          fi
        '') buckets)}

        echo "MinIO infrastructure ready."
      '';
      depends_on = {
        minio.condition = "process_healthy";
      };
      availability = {
        restart = "no";
      };
    };
  };
}
