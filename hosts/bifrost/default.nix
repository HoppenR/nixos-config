{ ... }:
{
  imports = [
    ../../roles/router.nix
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = true;
      extraPools = [ "tank" ];
    };
    kernel.sysctl = {
      "vm.swappiness" = 120;
      "vm.page-cluster" = 0;
    };
  };

  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
  networking = {
    hostId = "80a98287";
    hostName = "bifrost";
  };
  systemd.network = {
    links = {
      "10-lan1" = {
        linkConfig.Name = "lan1";
        matchConfig.MACAddress = "64:62:66:25:7e:bd";
      };
      "10-lan2" = {
        linkConfig.Name = "lan2";
        matchConfig.MACAddress = "64:62:66:25:7e:be";
      };
      "10-lan3" = {
        linkConfig.Name = "lan3";
        matchConfig.MACAddress = "64:62:66:25:7e:bf";
      };
      "10-wan0" = {
        linkConfig.Name = "wan0";
        matchConfig.MACAddress = "64:62:66:25:7e:c0";
      };
      "10-wlan-24" = {
        matchConfig.MACAddress = "00:0a:52:0e:e4:14";
        linkConfig.Name = "wlan_24";
      };
      "10-wlan-5" = {
        matchConfig.MACAddress = "00:0a:52:0e:e4:15";
        linkConfig.Name = "wlan_5";
      };
    };
  };

  hardware = {
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
  };

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };

  system.stateVersion = "25.11";
}
