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
    ../../roles/logic.nix
    ./hardware-configuration.nix
  ];

  boot = {
    zfs = {
      forceImportRoot = true;
      extraPools = [ "tank" ];
    };
  };

  networking = {
    hostId = "8425e349";
    hostName = "skadi";
  };
  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "weekly";
      };
    };
  };
  systemd.network = {
    links = {
      "20-lan0" = {
        matchConfig.MACAddress = "bc:24:11:51:3b:c5";
        linkConfig.Name = "lan0";
      };
    };
    netdevs = {
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
      "40-lan0" = {
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
        domains = [ config.networking.domain ];
        networkConfig = {
          Address = [
            "${net.ip net.mgmt config.networking.hostName}/24"
            "${net.ip6 net.mgmt config.networking.hostName}/64"
          ];
          DNS = [
            (net.ip net.mgmt gateway)
            (net.ip6 net.mgmt gateway)
          ];
          IPv4ReversePathFilter = "strict";
          IPv6AcceptRA = false;
          NTP = [
            (net.ip net.mgmt gateway)
            (net.ip6 net.mgmt gateway)
          ];
          MulticastDNS = true;
        };
        routes = [
          {
            Gateway = net.ip net.mgmt gateway;
            GatewayOnLink = true;
          }
          {
            Gateway = net.ip6 net.mgmt gateway;
            GatewayOnLink = true;
          }
        ];
      };
      "50-vlan-guest" = {
        matchConfig.Name = "vlan-guest";
        networkConfig = {
          Address = [
            "${net.ip net.guest config.networking.hostName}/24"
            "${net.ip6 net.guest config.networking.hostName}/64"
          ];
          DNS = [
            (net.ip net.guest gateway)
            (net.ip6 net.guest gateway)
          ];
          IPv4ReversePathFilter = "strict";
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          MulticastDNS = true;
        };
        routes = [
          {
            Gateway = net.ip net.guest gateway;
            GatewayOnLink = true;
          }
          {
            Gateway = net.ip6 net.guest gateway;
            GatewayOnLink = true;
          }
        ];
      };
    };
  };
  system.stateVersion = "25.11";
}
