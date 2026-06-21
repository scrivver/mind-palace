{
  description = "Mind Palace — cold data storage, labeling, and retrieval system with OAuth2 support.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              "minio-2025-10-15T17-29-55Z"
            ];
          };
        };

        postgresqlInfra = import ./infra/postgresql.nix { inherit pkgs; };
        rabbitmqInfra = import ./infra/rabbitmq.nix { inherit pkgs; };
        minioInfra = import ./infra/minio.nix { inherit pkgs; };
        caddyInfra = import ./infra/caddy.nix { inherit pkgs; };
        authentikInfra = import ./infra/authentik.nix { inherit pkgs; };

        waitForFile = path: label: ''
          until [ -f "${path}" ]; do
            echo "Waiting for ${label}..."
            sleep 1
          done
        '';

        waitForOidcDiscovery = ''
          until ${pkgs.curl}/bin/curl -fsS "$OIDC_ISSUER_URL.well-known/openid-configuration" >/dev/null; do
            echo "Waiting for Authentik OIDC discovery..."
            sleep 2
          done
        '';

        devAppProcesses = {
          reliquary-api = {
            command = pkgs.writeShellScript "mind-palace-dev-reliquary-api" ''
              set -euo pipefail
              ${waitForFile "$DATA_DIR/minio/api_port" "MinIO port"}
              ${waitForFile "$DATA_DIR/rabbitmq/amqp_port" "RabbitMQ port"}
              source "$PROJECT_ROOT/bin/load-infra-env"
              export LISTEN_ADDR="$DATA_DIR/reliquary/backend.sock"
              export PORT=8080
              cd "$PROJECT_ROOT/reliquary/backend"
              exec ${pkgs.air}/bin/air
            '';
            depends_on = {
              minio-setup.condition = "process_completed_successfully";
              rabbitmq.condition = "process_healthy";
            };
          };

          reliquary-thumbnail-worker = {
            command = pkgs.writeShellScript "mind-palace-dev-reliquary-thumbnail-worker" ''
              set -euo pipefail
              ${waitForFile "$DATA_DIR/minio/api_port" "MinIO port"}
              ${waitForFile "$DATA_DIR/rabbitmq/amqp_port" "RabbitMQ port"}
              source "$PROJECT_ROOT/bin/load-infra-env"
              cd "$PROJECT_ROOT/reliquary/backend"
              exec ${pkgs.go}/bin/go run ./cmd/reliquary-thumbnail-worker
            '';
            depends_on = {
              minio-setup.condition = "process_completed_successfully";
              rabbitmq.condition = "process_healthy";
            };
          };

          engram-api = {
            command = pkgs.writeShellScript "mind-palace-dev-engram-api" ''
              set -euo pipefail
              source "$PROJECT_ROOT/bin/load-infra-env"
              ${waitForOidcDiscovery}
              export PORT=8081
              cd "$PROJECT_ROOT/engram/backend"
              exec ${pkgs.air}/bin/air
            '';
            depends_on = {
              authentik-setup.condition = "process_completed_successfully";
              postgres-init.condition = "process_completed_successfully";
            };
          };

          engram-ingestion = {
            command = pkgs.writeShellScript "mind-palace-dev-engram-ingestion" ''
              set -euo pipefail
              ${waitForFile "$DATA_DIR/rabbitmq/amqp_port" "RabbitMQ port"}
              source "$PROJECT_ROOT/bin/load-infra-env"
              cd "$PROJECT_ROOT/engram/ingestion"
              exec ${pkgs.uv}/bin/uv run main.py
            '';
            depends_on = {
              postgres-init.condition = "process_completed_successfully";
              rabbitmq.condition = "process_healthy";
              minio-setup.condition = "process_completed_successfully";
            };
          };

          synapse-worker = {
            command = pkgs.writeShellScript "mind-palace-dev-synapse-worker" ''
              set -euo pipefail
              ${waitForFile "$DATA_DIR/rabbitmq/amqp_port" "RabbitMQ port"}
              source "$PROJECT_ROOT/bin/load-infra-env"
              cd "$PROJECT_ROOT/synapse"
              exec ${pkgs.go}/bin/go run ./cmd/synapse-worker
            '';
            depends_on = {
              rabbitmq.condition = "process_healthy";
              minio-setup.condition = "process_completed_successfully";
            };
          };

          synapse-reconciler = {
            command = pkgs.writeShellScript "mind-palace-dev-synapse-reconciler" ''
              set -euo pipefail
              ${waitForFile "$DATA_DIR/rabbitmq/amqp_port" "RabbitMQ port"}
              source "$PROJECT_ROOT/bin/load-infra-env"
              cd "$PROJECT_ROOT/synapse"
              exec ${pkgs.go}/bin/go run ./cmd/synapse-reconciler
            '';
            depends_on = {
              synapse-worker.condition = "process_started";
              engram-api.condition = "process_started";
            };
          };

          app = {
            command = pkgs.writeShellScript "mind-palace-dev-app" ''
              set -euo pipefail
              source "$PROJECT_ROOT/bin/load-infra-env"
              cd "$PROJECT_ROOT"
              exec "$PROJECT_ROOT/bin/start-app"
            '';
            depends_on = {
              caddy.condition = "process_healthy";
              reliquary-api.condition = "process_started";
              engram-api.condition = "process_started";
            };
          };
        };

        yamlFormat = pkgs.formats.yaml {};
        processComposeConfig = yamlFormat.generate "process-compose.yaml" {
          version = "0.5";
          processes =
            postgresqlInfra.processes //
            rabbitmqInfra.processes //
            minioInfra.processes //
            caddyInfra.processes //
            authentikInfra.processes;
        };
        devProcessComposeConfig = yamlFormat.generate "dev-process-compose.yaml" {
          version = "0.5";
          processes =
            postgresqlInfra.processes //
            rabbitmqInfra.processes //
            minioInfra.processes //
            caddyInfra.processes //
            authentikInfra.processes //
            devAppProcesses;
        };

        infraShell = import ./shells/infra.nix {
          inherit pkgs processComposeConfig devProcessComposeConfig;
        };
        devShellNix = import ./shells/dev.nix { inherit pkgs infraShell; };

      in
      {
        packages = {
          mind-palace-app-web = import ./nix/app-web.nix { inherit pkgs; };
          mind-palace-app-container = import ./nix/app-web-container.nix { inherit pkgs; };
          mind-palace-ingress-container = import ./nix/ingress-container.nix { inherit pkgs; };
          default = self.packages.${system}.mind-palace-ingress-container;
        };

        devShells = rec {
          infra = infraShell;
          dev = devShellNix;
          default = dev;
        };
      }
    );
}
