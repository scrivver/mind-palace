{ pkgs, processComposeConfig }:

pkgs.mkShell {
  name = "mind-palace-infra-shell";
  buildInputs = [
    pkgs.authentik
    pkgs.postgresql
    pkgs.redis
    pkgs.minio
    pkgs.minio-client
    pkgs.process-compose
    pkgs.python3
    pkgs.curl
  ];

  shellHook = ''
    export SHELL=${pkgs.bash}/bin/bash
    export PATH="$PWD/bin:$PATH"

    export DATA_DIR="$PWD/.data"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/minio"
    mkdir -p "$DATA_DIR/authentik/postgres"
    mkdir -p "$DATA_DIR/authentik/redis"

    # Generate process-compose config
    cp -f ${processComposeConfig} "$DATA_DIR/process-compose.yaml"

    # Process-compose unix socket path
    export PC_SOCKET="$DATA_DIR/process-compose.sock"

    # MinIO S3 port files
    export MINIO_API_PORT_FILE="$DATA_DIR/minio/api_port"
    export MINIO_CONSOLE_PORT_FILE="$DATA_DIR/minio/console_port"

    # Authentik files
    export AUTHENTIK_PG_SOCKET_DIR_FILE="$DATA_DIR/authentik/pg_socket_dir"
    export AUTHENTIK_REDIS_PORT_FILE="$DATA_DIR/authentik/redis_port"
    export AUTHENTIK_SERVER_PORT_FILE="$DATA_DIR/authentik/server_port"
  '';
}
