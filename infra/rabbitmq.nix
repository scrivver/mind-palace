{ pkgs, queues ? [
  { name = "engram.ingest"; durable = true; }
  { name = "synapse.jobs"; durable = true; }
] }:
let
  definitions = builtins.toJSON {
    vhosts = [ { name = "/"; } ];

    users = [ {
      name = "guest";
      password_hash = "/EKkHapb6J8jiJWy2l72TQt16OTLERZmJK5A8gUVYiguBGx5";
      hashing_algorithm = "rabbit_password_hashing_sha256";
      tags = [ "administrator" ];
    } ];

    permissions = [ {
      user = "guest";
      vhost = "/";
      configure = ".*";
      write = ".*";
      read = ".*";
    } ];

    queues = map (q: {
      name = q.name;
      vhost = "/";
      durable = q.durable;
      auto_delete = false;
      arguments = {};
    }) queues;

    bindings = map (q: {
      source = "amq.direct";
      vhost = "/";
      destination = q.name;
      destination_type = "queue";
      routing_key = q.name;
      arguments = {};
    }) queues;
  };

  definitionsFile = pkgs.writeText "rabbitmq-definitions.json" definitions;
in
{
  processes = {
    rabbitmq = {
      command = pkgs.writeShellScript "start-rabbitmq" ''
        set -euo pipefail

        RABBITMQ_DIR="$DATA_DIR/rabbitmq"
        mkdir -p "$RABBITMQ_DIR"

        AMQP_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); p=s.getsockname()[1]; s.close(); print(p if p < 45000 else p - 30000)')
        MGMT_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); p=s.getsockname()[1]; s.close(); print(p)')
        DIST_PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); p=s.getsockname()[1]; s.close(); print(p)')
        echo "$AMQP_PORT" > "$RABBITMQ_DIR/amqp_port"
        echo "$MGMT_PORT" > "$RABBITMQ_DIR/mgmt_port"

        export RABBITMQ_DIST_PORT="$DIST_PORT"
        export RABBITMQ_MNESIA_BASE="$RABBITMQ_DIR/mnesia"
        export RABBITMQ_LOG_BASE="$RABBITMQ_DIR/log"
        export RABBITMQ_SCHEMA_DIR="$RABBITMQ_DIR/schema"
        export RABBITMQ_GENERATED_CONFIG_DIR="$RABBITMQ_DIR/config"
        export RABBITMQ_NODE_PORT="$AMQP_PORT"
        export RABBITMQ_NODENAME="mind-palace@localhost"
        export RABBITMQ_PLUGINS_DIR="${pkgs.rabbitmq-server}/plugins"
        export RABBITMQ_ENABLED_PLUGINS_FILE="$RABBITMQ_DIR/enabled_plugins"

        mkdir -p "$RABBITMQ_MNESIA_BASE" "$RABBITMQ_LOG_BASE" "$RABBITMQ_SCHEMA_DIR" "$RABBITMQ_GENERATED_CONFIG_DIR"

        echo '[rabbitmq_management].' > "$RABBITMQ_ENABLED_PLUGINS_FILE"

        cat > "$RABBITMQ_DIR/rabbitmq.conf" <<RMQEOF
        listeners.tcp.default = $AMQP_PORT
        management.tcp.port = $MGMT_PORT
        default_user = guest
        default_pass = guest
        loopback_users = none
        management.load_definitions = ${definitionsFile}
        RMQEOF

        export RABBITMQ_CONFIG_FILE="$RABBITMQ_DIR/rabbitmq"
        exec ${pkgs.rabbitmq-server}/bin/rabbitmq-server
      '';
      readiness_probe = {
        exec.command = pkgs.writeShellScript "rabbitmq-ready" ''
          AMQP_PORT=$(cat "$DATA_DIR/rabbitmq/amqp_port" 2>/dev/null) || exit 1
          ${pkgs.rabbitmq-server}/bin/rabbitmqctl --node mind-palace@localhost status >/dev/null 2>&1
        '';
        initial_delay_seconds = 5;
        period_seconds = 3;
      };
    };
  };
}
