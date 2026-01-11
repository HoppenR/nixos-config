{ ... }:
{
  imports = [
    ../../roles/workstation.nix
    ../../relations
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = false;
      extraPools = [ "tank" ];
    };
  };

  services = {
    fwupd = {
      enable = true;
    };
    tlp = {
      enable = true;
      settings = {
        SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 70;
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      };
    };
    zfs = {
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
  };

  networking = {
    bonds = {
      lan0 = {
        interfaces = [
          "dock-lan"
          "laptop-lan"
        ];
        driverOptions = {
          miimon = "100";
          mode = "active-backup";
          primary = "dock-lan";
        };
      };
    };
    hostId = "007f0200";
    hostName = "rime";
    useDHCP = false;
  };

  systemd.network.links = {
    "20-dock-lan" = {
      matchConfig.MACAddress = "84:ba:59:74:c0:bc";
      linkConfig.Name = "dock-lan";
    };
    "20-laptop-lan" = {
      matchConfig.MACAddress = "74:5d:22:39:03:cf";
      linkConfig.Name = "laptop-lan";
    };
    "20-laptop-wifi" = {
      matchConfig.MACAddress = "04:7b:cb:c1:96:22";
      linkConfig.Name = "laptop-wifi";
    };
  };
  system.stateVersion = "25.11";
}
