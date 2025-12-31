{
  config,
  lib,
  roles,
  ...
}:

let
  zreplPort = 8219;
  zreplTypes = [
    "push"
    "sink"
  ];
in
{
  options.lab.zrepl = {
    enable = lib.mkEnableOption "enable zrepl lab configuration";
    type = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum zreplTypes);
      default = null;
      description = "The zrepl lab role";
    };
  };

  config = lib.mkIf config.lab.zrepl.enable {
    sops.secrets = {
      "zrepl-storage-key".key = "zrepl/storage-key";
      "zrepl-logic-key".key = "zrepl/logic-key";
    };

    networking.firewall.allowedTCPPorts = lib.mkIf (config.lab.zrepl.type == "sink") [ zreplPort ];
    services.zrepl = {
      enable = true;
      settings = {
        jobs = [
          (lib.mkIf (config.lab.zrepl.type == "push") {
            # For running zrepl job [skadi:tank -> hoddmimir:holt]
            type = "push";
            name = "push_db_${roles.storage.hostName}";
            connect = {
              type = "tls";
              address = "${roles.storage.ipv4}:${toString zreplPort}";
              ca = "${../../certs/ca.crt}";
              cert = "${../../certs/logic01.crt}";
              key = config.sops.secrets."zrepl-logic-key".path;
              server_cn = "storage01";
            };
            filesystems = {
              "tank/replicated/db<" = true;
            };
            pruning = {
              keep_sender = [
                { type = "not_replicated"; }
                {
                  type = "last_n";
                  count = 4;
                }
              ];
              keep_receiver = [
                {
                  type = "grid";
                  grid = "1x24h(keep=all) | 6x1d | 3x1w | 3x30d";
                  regex = "^zrepl_";
                }
              ];
            };
            replication = {
              protection = {
                initial = "guarantee_resumability";
                incremental = "guarantee_incremental";
              };
            };
            send = {
              send_properties = true;
            };
            snapshotting = {
              interval = "1d";
              prefix = "zrepl_";
              timestamp_format = "iso-8601";
              type = "periodic";
            };
          })
          (lib.mkIf (config.lab.zrepl.type == "sink") {
            # For running zrepl job [hoddmimir:holt <- skadi:tank]
            type = "sink";
            name = "sink_db_${roles.logic.hostName}";
            root_fs = "holt";
            recv = {
              placeholder.encryption = "inherit";
              properties.override = {
                canmount = "off";
                copies = "2";
                mountpoint = "none";
                readonly = "on";
              };
            };
            serve = {
              type = "tls";
              listen = ":${toString zreplPort}";
              ca = "${../../certs/ca.crt}";
              cert = "${../../certs/storage01.crt}";
              key = config.sops.secrets."zrepl-storage-key".path;
              client_cns = [ "logic01" ];
            };
          })
        ];
      };
    };
  };
}
