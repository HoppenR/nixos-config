{
  lib,
  roles,
  ...
}:
{
  # TODO: this file shouldn't really be roles/common if it is this setup specific
  config = {
    services.syncthing = {
      enable = true;
      configDir = "/var/lib/syncthing";
      dataDir = "/replicated/apps/syncthing";
      guiAddress = "${roles.logic.ipv4}:8384";
    };
    systemd.services = {
      syncthing = {
        after = [ "rclone-replicated-apps.service" ];
        requires = [ "rclone-replicated-apps.service" ];
        serviceConfig.StateDirectory = "syncthing";
      };
    };
    users.users.syncthing.createHome = lib.mkForce false;
    networking.firewall = {
      allowedTCPPorts = [
        8384
        22000
      ];
      allowedUDPPorts = [
        22000
        21027
      ];
    };
  };
}
