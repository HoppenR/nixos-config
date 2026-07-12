{ ... }:
{
  imports = [
    ../../roles/workstation.nix
    ./hardware-configuration.nix
    # TODO uncomment disko.nix and remove fileSystems entries
    # ./disko.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = true;
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
    hostId = "007f0200";
    hostName = "rime";
  };
  systemd.network = {
    enable = true;
    wait-online.enable = false;
    links = {
      "20-dock-lan" = {
        linkConfig.Name = "dock-lan";
        matchConfig.MACAddress = "84:ba:59:74:c0:bc";
      };
      "20-laptop-lan" = {
        linkConfig.Name = "laptop-lan";
        matchConfig.MACAddress = "74:5d:22:39:03:cf";
      };
      "20-laptop-wifi" = {
        linkConfig.Name = "laptop-wifi";
        matchConfig.MACAddress = "04:7b:cb:c1:96:22";
      };
    };
  };

  system.stateVersion = "25.11";
}
