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
          handle /api/reliquary/* {
            uri strip_prefix /api/reliquary
            reverse_proxy ''${RELIQUARY_BACKEND}
          }

          # Engram API
          handle /api/engram/* {
            uri strip_prefix /api/engram
            reverse_proxy ''${ENGRAM_BACKEND}
          }

          # Synapse API (Future)
          handle /api/synapse/* {
            uri strip_prefix /api/synapse
            reverse_proxy ''${SYNAPSE_BACKEND}
          }

          # Shared Storage (MinIO)
          #
          # A presigned URL is a bearer credential: anyone holding it can fetch
          # the object until it expires. forward_auth closes that by asking
          # Reliquary to authorize every request first, so a leaked link is
          # useless without a valid session that also owns the key.
          handle /storage/* {
            forward_auth ''${RELIQUARY_BACKEND} {
              uri /api/auth/check
            }

            uri strip_prefix /storage
            reverse_proxy 127.0.0.1:''${MINIO_PORT} {
              header_up Host 127.0.0.1:''${MINIO_PORT}
              # The client sends a Bearer token for forward_auth above, but the
              # object itself is authenticated by the presigned query signature.
              # MinIO rejects a request carrying both with "request has multiple
              # authentication types", so the token stops here.
              header_up -Authorization
              header_down -Access-Control-Allow-Origin
              header_down -Access-Control-Allow-Methods
              header_down -Access-Control-Allow-Headers
            }
          }

          # Health check
          handle /health {
            respond "OK" 200
          }

          # Flutter web dev server — proxies everything else so the app
          # and its relative API URLs are served from the same origin.
          handle {
            reverse_proxy 127.0.0.1:3000
          }
        }
        CADDYEOF

        echo "$PROXY_PORT" > "$CADDY_DIR/port"
        echo "Caddy proxy starting on :$PROXY_PORT"
        echo "  /api/reliquary/* -> $RELIQUARY_BACKEND"
        echo "  /api/engram/*    -> $ENGRAM_BACKEND"
        echo "  /storage/*       -> auth check ($RELIQUARY_BACKEND) then 127.0.0.1:$MINIO_PORT"
        echo "  /*               -> 127.0.0.1:3000 (Flutter web dev server)"

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
