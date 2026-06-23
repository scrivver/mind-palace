{ pkgs }:

let
  caddyfile = pkgs.writeText "Caddyfile" ''
    {
      admin off
      persist_config off
    }

    :2080 {
      header Access-Control-Allow-Origin *
      header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
      header Access-Control-Allow-Headers "Accept, Authorization, Content-Type"

      @options method OPTIONS
      handle @options {
        respond 204
      }

      handle /api/reliquary/* {
        uri strip_prefix /api/reliquary
        reverse_proxy reliquary-api:8080
      }

      handle /api/engram/* {
        uri strip_prefix /api/engram
        reverse_proxy engram-api:8081
      }

      handle /storage/* {
        uri strip_prefix /storage
        reverse_proxy minio:9000 {
          header_up Host minio:9000
          header_down -Access-Control-Allow-Origin
          header_down -Access-Control-Allow-Methods
          header_down -Access-Control-Allow-Headers
        }
      }

      handle /health {
        respond "OK" 200
      }

      handle {
        respond "Mind Palace dogfood ingress is running" 200
      }
    }
  '';

  healthcheck = pkgs.writeShellScriptBin "mind-palace-ingress-healthcheck" ''
    exec ${pkgs.curl}/bin/curl --fail --silent --show-error \
      http://127.0.0.1:2080/health >/dev/null
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "mind-palace-ingress";
  tag = "latest";

  contents = [
    pkgs.caddy
    pkgs.curl
    pkgs.cacert
    healthcheck
  ];

  extraCommands = ''
    mkdir -p etc/caddy
    cp ${caddyfile} etc/caddy/Caddyfile
  '';

  config = {
    Entrypoint = [
      "${pkgs.caddy}/bin/caddy"
      "run"
      "--config"
      "/etc/caddy/Caddyfile"
      "--adapter"
      "caddyfile"
    ];
    ExposedPorts = { "2080/tcp" = {}; };
    Env = [ "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" ];
  };
}
