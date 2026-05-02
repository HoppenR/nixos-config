{
  config,
  inventory,
  topology,
  net,
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
      "30-vlan-mgmt" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-mgmt";
        };
        vlanConfig.Id = 10;
      };
      "30-vlan-guest" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-guest";
        };
        vlanConfig.Id = 20;
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
      "45-lan0" = {
        matchConfig.Name = "lan0";
        vlan = [
          "vlan-mgmt"
          "vlan-guest"
        ];
        networkConfig = {
          DHCP = false;
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          LinkLocalAddressing = false;
        };
      };
      "50-vlan-mgmt" = {
        # TODO: add different vrfs for each vlan on this system
        matchConfig.Name = "vlan-mgmt";
        addresses = [
          {
            Address = "${net.ip net.mgmt config.networking.hostName}/24";
            RouteMetric = 10;
          }
          {
            Address = "${net.ip6 net.mgmt config.networking.hostName}/64";
            RouteMetric = 10;
          }
        ];
        domains = [ config.networking.domain ];
        networkConfig = {
          DNS = [
            (net.ip net.mgmt gateway)
            (net.ip6 net.mgmt gateway)
          ];
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          NTP = [
            (net.ip net.mgmt gateway)
            (net.ip6 net.mgmt gateway)
          ];
          MulticastDNS = true;
        };
        routes = [
          {
            Destination = "${net.ip net.mgmt gateway}/32";
            Metric = 10;
          }
          {
            Gateway = net.ip net.mgmt gateway;
            GatewayOnLink = true;
            Metric = 10;
          }
          {
            Destination = "${net.ip6 net.mgmt gateway}/128";
            Metric = 10;
          }
          {
            Gateway = net.ip6 net.mgmt gateway;
            GatewayOnLink = true;
            Metric = 10;
          }
        ];
      };
      "50-vlan-guest" = {
        matchConfig.Name = "vlan-guest";
        addresses = [
          {
            Address = "${net.ip net.guest config.networking.hostName}/24";
            RouteMetric = 10;
          }
          {
            Address = "${net.ip6 net.guest config.networking.hostName}/64";
            RouteMetric = 10;
          }
        ];
        networkConfig = {
          DNS = [
            (net.ip net.guest gateway)
            (net.ip6 net.guest gateway)
          ];
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          MulticastDNS = true;
        };
        routes = [
          {
            Destination = "${net.ip net.guest gateway}/32";
            Metric = 10;
          }
          {
            Gateway = net.ip net.guest gateway;
            GatewayOnLink = true;
            Metric = 10;
          }
          {
            Destination = "${net.ip6 net.guest gateway}/128";
            Metric = 10;
          }
          {
            Gateway = net.ip6 net.guest gateway;
            GatewayOnLink = true;
            Metric = 10;
          }
        ];
      };
      "50-laptop-wifi" = {
        matchConfig.Name = "laptop-wifi";
        domains = [ config.networking.domain ];
        networkConfig = {
          DHCP = true;
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
