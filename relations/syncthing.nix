{
  lib,
  config,
  topology,
  ...
}:
let
  server = "skadi";
  clients = [ "rime" ];
in
{
  config = lib.mkMerge [
    (lib.mkIf (lib.elem config.networking.hostName clients) {
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
    (lib.mkIf (config.networking.hostName == server) {
      services.syncthing = {
        enable = true;
        configDir = "/var/lib/syncthing";
        dataDir = "/replicated/apps/syncthing";
        guiAddress = "${topology.skadi.ipv4}:8384";
        openDefaultPorts = true;
      };
      systemd.services = {
        syncthing = {
          after = [ "rclone-replicated-apps.service" ];
          requires = [ "rclone-replicated-apps.service" ];
          serviceConfig.StateDirectory = "syncthing";
        };
      };
      users.users.syncthing.createHome = lib.mkForce false;
      networking.firewall.allowedTCPPorts = [ 8384 ];
    })
  ];
}
