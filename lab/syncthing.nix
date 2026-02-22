{
  lib,
  config,
  inventory,
  relations,
  ...
}:
let
  relSync = relations.syncthing;
  relMount = relations.rcloneMounts;
in
{
  config = lib.mkMerge [
    (lib.mkIf relMount.isActive {
      lab.rcloneMounts.services."syncthing" = {
        enable = true;
        sshKeyPublic = lib.mkIf relMount.isHost ../keys/id_sftp_syncthing.pub;
        sshKeySecret = lib.mkIf relMount.isClient config.sops.secrets."sftp-syncthing-ssh-key".path;
      };
    })
    (lib.mkIf (relSync.isActive && relSync.isClient) {
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
    (lib.mkIf (relSync.isActive && relSync.isHost) {
      networking.firewall.allowedTCPPorts = [ 8384 ];
      services.syncthing = {
        enable = true;
        configDir = "/var/lib/syncthing";
        dataDir = "/replicated/apps/syncthing/remote";
        guiAddress = "${inventory.${relSync.host}.ipv4}:8384";
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
          bindsTo = [ "rclone-syncthing.service" ];
          serviceConfig.StateDirectory = "syncthing";
        };
      };
      users.users.syncthing = {
        createHome = lib.mkForce false;
      };
    })
  ];
}
