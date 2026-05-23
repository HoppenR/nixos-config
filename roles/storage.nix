{
  config,
  lib,
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
    ./common.nix
  ];

  networking = {
    firewall = {
      interfaces."vlan-mgmt".allowedUDPPorts = [
        # mDNS
        5353
      ];
    };
  };

  console.colors = lib.attrValues {
    c01_black = "1a1c19";
    c02_red = "8b2635";
    c03_green = "52691e";
    c04_yellow = "8a4a02";
    c05_blue = "053318";
    c06_magenta = "5d3a3a";
    c07_cyan = "2d5a27";
    c08_white = "d2b48c";
    c09_blackFg = "4a4a4a";
    c10_redFg = "c0392b";
    c11_greenFg = "7eb356";
    c12_yellowFg = "e67e22";
    c13_blueFg = "f39c12";
    c14_magentaFg = "a0522d";
    c15_cyanFg = "2ecc71";
    c16_whiteFg = "fdf5e6";
  };

  home-manager = {
    users = {
      ${config.lab.mainUser} = import ../home/storage.nix;
    };
  };

  lab = {
    greetd = {
      enable = true;
      theme = "container=blue;action=yellow;button=yellow;window=black";
      useZshLogin = true;
    };
    openssh.enable = true;
  };

  services = {
    pipewire.enable = false;
  };

  systemd.network = {
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
}
