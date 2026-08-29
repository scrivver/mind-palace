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

      # A presigned URL is a bearer credential: anyone holding it can fetch the
      # object until it expires. forward_auth asks Reliquary to authorize every
      # request first, so a leaked link is useless without a session that also
      # owns the key.
      handle /storage/* {
        forward_auth reliquary-api:8080 {
          uri /api/auth/check
        }

        uri strip_prefix /storage
        reverse_proxy minio:9000 {
          header_up Host minio:9000
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

      # Flutter does not content-hash these, so without an explicit directive the
      # browser applies heuristic caching and an upgraded deployment keeps
      # serving the previous bundle. That fails in a way that is hard to read:
      # an old bundle talks to a new API, and only the calls whose contract
      # changed break.
      #
      # `no-cache` means revalidate, not "don't store", but it costs a full
      # re-download here rather than a 304: Nix pins every file in the store to
      # mtime epoch+1, and Caddy omits ETag and Last-Modified for such files, so
      # the browser has no validator to send. Cheap revalidation would need the
      # build to stamp a real per-release mtime on /srv/web.
      @bundle path / /index.html /flutter_bootstrap.js /flutter_service_worker.js /main.dart.js /version.json

      handle {
        root * /srv/web

        # `route` pins the execution order: Caddy would otherwise sort `header`
        # ahead of `try_files`, so a deep link like /gallery would be matched on
        # its original path and served an unmarked index.html.
        route {
          try_files {path} /index.html
          header @bundle Cache-Control "no-cache"
          file_server
        }
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
