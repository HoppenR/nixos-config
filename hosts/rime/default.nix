{
  config,
  inventory,
  topology,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  gateway = topology.${machine.topology}.gateway;
in
{
  imports = [
    ../../roles/workstation.nix
    ./hardware-configuration.nix
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
    netdevs = {
      "30-lan0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "lan0";
          MACAddress = "74:5d:22:39:03:cf";
        };
        bondConfig = {
          Mode = "active-backup";
          MIIMonitorSec = "200ms";
        };
      };
    };
    networks = {
      "40-dock-lan0" = {
        matchConfig.Name = "dock-lan";
        networkConfig = {
          Bond = "lan0";
          PrimarySlave = true;
        };
      };
      "40-laptop-lan0" = {
        matchConfig.Name = "laptop-lan";
        networkConfig = {
          Bond = "lan0";
        };
      };
      "45-lan0-static" = {
        matchConfig.Name = "lan0";
        addresses = [
          {
            Address = "${machine.ipv4}/24";
            RouteMetric = 10;
          }
          {
            Address = "${machine.ipv6}/64";
            RouteMetric = 10;
          }
        ];
        networkConfig = {
          DNS = [
            inventory.${gateway}.ipv4
            inventory.${gateway}.ipv6
          ];
          Domains = [ config.networking.domain ];
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          NTP = [
            inventory.${gateway}.ipv4
            inventory.${gateway}.ipv6
          ];
          MulticastDNS = true;
        };
        routes = [
          {
            Destination = "${inventory.${gateway}.ipv4}/32";
            Metric = 10;
          }
          {
            Gateway = inventory.${gateway}.ipv4;
            GatewayOnLink = true;
            Metric = 10;
          }
          {
            Destination = "${inventory.${gateway}.ipv6}/128";
            Metric = 10;
          }
          {
            Gateway = inventory.${gateway}.ipv6;
            GatewayOnLink = true;
            Metric = 10;
          }
        ];
      };
      "50-laptop-wifi" = {
        matchConfig.Name = "laptop-wifi";
        networkConfig = {
          DHCP = true;
          Domains = [ config.networking.domain ];
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = true;
          MulticastDNS = "resolve";
        };
        dhcpV4Config = {
          RouteMetric = 100;
        };
        ipv6AcceptRAConfig = {
          RouteMetric = 100;
        };
      };
    };
  };
  system.stateVersion = "25.11";
}
