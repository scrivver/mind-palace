{ pkgs, infraShell }:

pkgs.mkShell {
  name = "mind-palace-dev-shell";
  inputsFrom = [ infraShell ];
  buildInputs = [
    pkgs.flutter
    pkgs.dart
    pkgs.jdk17
    pkgs.android-tools
    pkgs.cmake
    pkgs.ninja
    pkgs.pkg-config
    pkgs.gtk3
    pkgs.glib
    pkgs.sysprof
    pkgs.xz
    pkgs.clang
    pkgs.zenity
    pkgs.libsecret
    pkgs.nodejs
    pkgs.go
    pkgs.gopls
    pkgs.gotools
    pkgs.python3
    pkgs.uv
    pkgs.minio-client
    pkgs.postgresql
    pkgs.postgresql
    pkgs.rabbitmq-server
    pkgs.caddy
    pkgs.ffmpeg
    pkgs.file # Provides libmagic
    pkgs.air
  ];

    shellHook = ''
    export CHROME_EXECUTABLE="$(which chromium 2>/dev/null || which google-chrome-stable 2>/dev/null || echo "")"

    # Export infrastructure paths and ports
    export DATA_DIR="$PWD/.data"
    export MINIO_API_PORT_FILE="$DATA_DIR/minio/api_port"
    export RABBITMQ_AMQP_PORT_FILE="$DATA_DIR/rabbitmq/amqp_port"
    export PROXY_PORT_FILE="$DATA_DIR/caddy/port"
    export PGHOST="$DATA_DIR/postgres"

    # Ensure runtime directories exist
    mkdir -p "$DATA_DIR/reliquary"
    mkdir -p "$DATA_DIR/engram"
    mkdir -p "$DATA_DIR/synapse"

    # Help python-magic find libmagic
    export LD_LIBRARY_PATH="${pkgs.file}/lib:''${LD_LIBRARY_PATH:-}"

    # Helper function to load env

    load-infra-env() {
      if [ -f "$MINIO_API_PORT_FILE" ]; then
        export MINIO_PORT=$(cat "$MINIO_API_PORT_FILE")
        export STORAGE_S3_ENDPOINT="http://127.0.0.1:$MINIO_PORT"
      fi
      if [ -f "$RABBITMQ_AMQP_PORT_FILE" ]; then
        export RABBITMQ_AMQP_PORT=$(cat "$RABBITMQ_AMQP_PORT_FILE")
      fi
      if [ -f "$PROXY_PORT_FILE" ]; then
        export PROXY_PORT=$(cat "$PROXY_PORT_FILE")
      fi
    }

    # Add bin to path
    export PATH="$PWD/bin:$PATH"

    # Prevent nix from leaking CMAKE_INSTALL_PREFIX into Flutter's Linux build
    unset cmakeFlags
  '';
}
