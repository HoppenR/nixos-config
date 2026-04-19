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
  };
  services = {
    zfs = {
      trim = {
        enable = true;
        interval = "monthly";
      };
    };
  };
  systemd.network = {
    links."20-lan0" = {
      matchConfig.MACAddress = "bc:24:11:14:eb:fb";
      linkConfig.Name = "lan0";
    };
    netdevs = {
      "30-vlan-mgmt" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-mgmt";
        };
        vlanConfig.Id = 10;
      };
    };
    networks = {
      "40-lan0" = {
        matchConfig.Name = "lan0";
        vlan = [ "vlan-mgmt" ];
        networkConfig = {
          DHCP = false;
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          LinkLocalAddressing = false;
        };
      };
      "50-vlan-mgmt" = {
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
    };
  };
  system.stateVersion = "25.11";
}
