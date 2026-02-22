{
  lib,
  config,
  topology,
  ...
}:
let
  server = "skadi";
  clients = [ "rime" ];
  isServer = config.networking.hostName == server;
  isClient = lib.elem config.networking.hostName clients;
in
{
  config = lib.mkMerge [
    {
      lab.rcloneMounts.services."syncthing" = {
        enable = true;
        sshKeyPublic = lib.mkIf config.lab.rcloneMounts.isMountHost ../keys/id_sftp_syncthing.pub;
        sshKeySecret = lib.mkIf isServer config.sops.secrets."sftp-syncthing-ssh-key".path;
      };
    }
    (lib.mkIf isClient {
      home-manager.users.${config.lab.mainUser} = {
        services.syncthing.enable = true;
      };
      networking.firewall = {
        allowedTCPPorts = [ 22000 ];
        allowedUDPPorts = [
          21027
          22000
        ];
      };
    })
    (lib.mkIf isServer {
      networking.firewall.allowedTCPPorts = [ 8384 ];
      services.syncthing = {
        enable = true;
        configDir = "/var/lib/syncthing";
        dataDir = "/replicated/apps/syncthing/remote";
        guiAddress = "${topology.skadi.ipv4}:8384";
        openDefaultPorts = true;
      };
      sops.secrets = {
        "sftp-syncthing-ssh-key" = {
          key = "sftp/syncthing-ssh-key";
          owner = config.users.users.syncthing.name;
          inherit (config.users.users.syncthing) group;
        };
      };
      systemd.services = {
        syncthing = {
          after = [ "rclone-syncthing.service" ];
          requires = [ "rclone-syncthing.service" ];
          serviceConfig.StateDirectory = "syncthing";
        };
      };
      users.users.syncthing = {
        createHome = lib.mkForce false;
      };
    })
  ];
}
