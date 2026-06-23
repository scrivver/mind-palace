{ pkgs }:

let
  appWeb = import ./app-web.nix { inherit pkgs; };
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

      handle /health {
        respond "OK" 200
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

      handle {
        root * /srv/web
        try_files {path} /index.html
        file_server
      }
    }
  '';

  healthcheck = pkgs.writeShellScriptBin "mind-palace-app-healthcheck" ''
    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      http://127.0.0.1:2080/health >/dev/null
    ${pkgs.curl}/bin/curl --fail --silent --show-error \
      http://127.0.0.1:2080/api/engram/api/health >/dev/null
    exec ${pkgs.curl}/bin/curl --fail --silent --show-error \
      http://127.0.0.1:2080/index.html >/dev/null
  '';
in
pkgs.dockerTools.buildLayeredImage {
  name = "mind-palace-app";
  tag = "latest";

  contents = [
    pkgs.caddy
    pkgs.cacert
    pkgs.curl
    healthcheck
  ];

  extraCommands = ''
    mkdir -p etc/caddy srv/web
    cp ${caddyfile} etc/caddy/Caddyfile
    cp -R ${appWeb}/. srv/web/
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
