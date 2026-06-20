{ pkgs, processComposeConfig, devProcessComposeConfig ? processComposeConfig }:

pkgs.mkShell {
  name = "mind-palace-infra-shell";
  buildInputs = [
    pkgs.authentik
    pkgs.postgresql
    pkgs.process-compose
    pkgs.python3
    pkgs.curl
  ];

  shellHook = ''
    export SHELL=${pkgs.bash}/bin/bash
    export PATH="$PWD/bin:$PATH"

    export DATA_DIR="$PWD/.data"
    mkdir -p "$DATA_DIR"
    mkdir -p "$DATA_DIR/authentik/postgres"

    # Generate process-compose configs
    cp -f ${processComposeConfig} "$DATA_DIR/process-compose.yaml"
    cp -f ${devProcessComposeConfig} "$DATA_DIR/dev-process-compose.yaml"

    # Process-compose unix socket path
    export PC_SOCKET="$DATA_DIR/process-compose.sock"
    export INFRA_PROCESS_COMPOSE_FILE="$DATA_DIR/process-compose.yaml"
    export DEV_PROCESS_COMPOSE_FILE="$DATA_DIR/dev-process-compose.yaml"

    # Authentik files
    export AUTHENTIK_PG_SOCKET_DIR_FILE="$DATA_DIR/authentik/pg_socket_dir"
    export AUTHENTIK_SERVER_PORT_FILE="$DATA_DIR/authentik/server_port"
  '';
}
