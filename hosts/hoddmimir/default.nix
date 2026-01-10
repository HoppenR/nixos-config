{ ... }:
{
  _module.args = {
    topology = import ../../topology.nix;
    identities = import ../../identities.nix;
  };
  imports = [
    ../../roles/storage.nix
    ../../relations
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = false;
      extraPools = [ "holt" ];
    };
  };

  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "monthly";
      };
    };
  };

  networking = {
    defaultGateway = {
      address = "192.168.0.1";
      interface = "lan0";
    };
    hostId = "299a21e5";
    hostName = "hoddmimir";
    useDHCP = false;
  };
  systemd.network.links = {
    "20-lan0" = {
      matchConfig.MACAddress = "bc:24:11:14:eb:fb";
      linkConfig.Name = "lan0";
    };
  };
  system.stateVersion = "25.11";
}
