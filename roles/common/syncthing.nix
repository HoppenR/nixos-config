{
  config,
  lib,
  pkgs,
  ...
}:
{
  config.services.syncthing = {
    enable = true;
    configDir = "/var/lib/syncthing";
    dataDir = "/replicated/apps/syncthing";
    guiAddress = "192.168.0.41:8384";
  };
  config.systemd.services = {
    syncthing = {
      serviceConfig.StateDirectory = "syncthing";
    };
  };
  config.networking.firewall = {
    allowedTCPPorts = [
      8384
      22000
    ];
    allowedUDPPorts = [
      22000
      21027
    ];
  };
}
