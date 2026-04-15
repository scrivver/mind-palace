{ pkgs, proxyPort ? "2080" }:
{
  processes = {
    caddy = {
      command = pkgs.writeShellScript "start-caddy" ''
        set -euo pipefail

        MINIO_PORT=$(cat "$DATA_DIR/minio/api_port")
        PROXY_PORT="${proxyPort}"
        
        # Backend addresses (can be overridden by env vars)
        RELIQUARY_BACKEND="unix/$DATA_DIR/reliquary/backend.sock"
        ENGRAM_BACKEND="127.0.0.1:8081"
        SYNAPSE_BACKEND="127.0.0.1:8082"

        CADDY_DIR="$DATA_DIR/caddy"
        mkdir -p "$CADDY_DIR"

        cat > "$CADDY_DIR/Caddyfile" <<CADDYEOF
        {
          admin off
          persist_config off
        }

        :''${PROXY_PORT} {
          header Access-Control-Allow-Origin *
          header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
          header Access-Control-Allow-Headers "Accept, Authorization, Content-Type"

          @options method OPTIONS
          handle @options {
            respond 204
          }

          # Reliquary API
          handle_path /api/reliquary/* {
            reverse_proxy ''${RELIQUARY_BACKEND}
          }

          # Engram API
          handle_path /api/engram/* {
            reverse_proxy ''${ENGRAM_BACKEND}
          }

          # Synapse API (Future)
          handle_path /api/synapse/* {
            reverse_proxy ''${SYNAPSE_BACKEND}
          }

          # Shared Storage (MinIO)
          handle /storage/* {
            uri strip_prefix /storage
            reverse_proxy 127.0.0.1:''${MINIO_PORT} {
              header_up Host 127.0.0.1:''${MINIO_PORT}
              header_down -Access-Control-Allow-Origin
              header_down -Access-Control-Allow-Methods
              header_down -Access-Control-Allow-Headers
            }
          }

          # Default: Health check or static files
          handle /health {
            respond "OK" 200
          }
        }
        CADDYEOF

        echo "$PROXY_PORT" > "$CADDY_DIR/port"
        echo "Caddy proxy starting on :$PROXY_PORT"
        echo "  /api/reliquary/* -> $RELIQUARY_BACKEND"
        echo "  /api/engram/*    -> $ENGRAM_BACKEND"
        echo "  /storage/*       -> 127.0.0.1:$MINIO_PORT"

        exec ${pkgs.caddy}/bin/caddy run --config "$CADDY_DIR/Caddyfile"
      '';
      depends_on = {
        minio.condition = "process_healthy";
      };
      readiness_probe = {
        exec.command = pkgs.writeShellScript "caddy-ready" ''
          PROXY_PORT=$(cat "$DATA_DIR/caddy/port" 2>/dev/null) || exit 1
          curl -sf "http://127.0.0.1:$PROXY_PORT/health" -o /dev/null 2>&1
        '';
        initial_delay_seconds = 2;
        period_seconds = 2;
      };
    };
  };

  inherit proxyPort;
}
