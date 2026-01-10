{ ... }:
{
  _module.args = {
    topology = import ../../topology.nix;
    identities = import ../../identities.nix;
  };
  imports = [
    ../../roles/logic.nix
    ../../relations
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = false;
      extraPools = [ "tank" ];
    };
  };

  networking = {
    defaultGateway = {
      address = "192.168.0.1";
      interface = "lan0";
    };
    hostId = "8425e349";
    hostName = "skadi";
    useDHCP = false;
  };
  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
  systemd.network.links = {
    "20-lan0" = {
      matchConfig.MACAddress = "bc:24:11:51:3b:c5";
      linkConfig.Name = "lan0";
    };
  };
  system.stateVersion = "25.11";
}
