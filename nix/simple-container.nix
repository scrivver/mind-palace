{ pkgs }:

{ name, command }:
let
  entrypoint = pkgs.writeShellScriptBin "${name}-entrypoint" ''
    set -euo pipefail
    exec ${pkgs.bash}/bin/bash -lc ${pkgs.lib.escapeShellArg command}
  '';
  healthcheck = pkgs.writeShellScriptBin "${name}-healthcheck" ''
    kill -0 1
  '';
in
pkgs.dockerTools.buildLayeredImage {
  inherit name;
  tag = "latest";

  contents = [
    entrypoint
    healthcheck
    pkgs.bash
    pkgs.coreutils
    pkgs.cacert
  ];

  config = {
    Entrypoint = [ "${entrypoint}/bin/${name}-entrypoint" ];
    Env = [ "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt" ];
  };
}
