{ ... }:
{
  imports = [
    ../../roles/storage.nix
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = true;
      extraPools = [ "holt" ];
    };
  };

  networking = {
    hostId = "299a21e5";
    hostName = "hoddmimir";
    useDHCP = false;
  };

  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "monthly";
      };
    };
  };
  systemd.network.links = {
    "20-lan0" = {
      matchConfig.MACAddress = "bc:24:11:14:eb:fb";
      linkConfig.Name = "lan0";
    };
  };
  system.stateVersion = "25.11";
}
