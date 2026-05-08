{
  config,
  lib,
  pkgs,
  inventory,
  topology,
  net,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  top = topology.${machine.topology};
in
{
  imports = [
    ./common.nix
  ];

  assertions = [
    {
      assertion =
        builtins.length config.networking.firewall.allowedTCPPorts == 0
        && builtins.length config.networking.firewall.allowedUDPPorts == 0;
      message = "Global list of allowed firewall ports must be empty.";
    }
    {
      assertion =
        builtins.length config.networking.firewall.interfaces."wan0".allowedTCPPorts == 0
        && builtins.length config.networking.firewall.interfaces."wan0".allowedUDPPorts == 0;
      message = "wan0 list of allowed firewall ports must be empty.";
    }
    {
      assertion =
        let
          ids = lib.mapAttrsToList (n: v: v.id) inventory;
        in
        builtins.length (lib.unique ids) == builtins.length ids;
    }
  ];

  boot.kernel.sysctl = {
    "net.ipv4.conf.all.arp_announce" = 2;
    "net.ipv4.conf.all.arp_filter" = 1;
    "net.ipv4.conf.all.arp_ignore" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.arp_announce" = 2;
    "net.ipv4.conf.default.arp_filter" = 1;
    "net.ipv4.conf.default.arp_ignore" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;

    "net.ipv6.conf.wan0.accept_ra" = 2;
    "net.vrf.strict_mode" = 1;
  };

  console.colors = lib.attrValues {
    c01_black = "2e3440";
    c02_red = "bf616a";
    c03_green = "a3be8c";
    c04_yellow = "d08770";
    c05_blue = "5e81ac";
    c06_magenta = "b48ead";
    c07_cyan = "88c0d0";
    c08_white = "e5e9f0";
    c09_blackFg = "4c566a";
    c10_redFg = "d08770";
    c11_greenFg = "8fbcbb";
    c12_yellowFg = "ebcb8b";
    c13_blueFg = "81a1c1";
    c14_magentaFg = "d08770";
    c15_cyanFg = "8fbcbb";
    c16_whiteFg = "eceff4";
  };

  environment = {
    systemPackages = (
      builtins.attrValues {
        inherit (pkgs)
          bridge-utils
          dig
          iw
          nload
          nmap
          tcpdump
          ;
      }
    );
  };

  home-manager = {
    users = {
      ${config.lab.mainUser} = import ../home/router.nix;
    };
  };

  lab = {
    chrony = {
      enable = true;
    };
    dnsmasq = {
      enable = true;
    };
    greetd = {
      enable = false;
    };
    hostapd = {
      enable = true;
      bssid24 = "00:0a:52:0e:e4:14";
      bssid5 = "00:0a:52:0e:e4:15";
    };
    namespaces = {
      mgmt = {
        enable = true;
        gatewayMac = "5a:6f:79:3a:33:1a";
        search = true;
        extraHosts = (
          lib.concatMapStrings (hostName: ''
            ${net.ip net.mgmt hostName} ${hostName}.${config.networking.domain}
            ${net.ip6 net.mgmt hostName} ${hostName}.${config.networking.domain}
          '') (lib.attrNames inventory)
        );
        firewall.extraForwardRules = ''
          iifname "vlan-mgmt" oifname "veth-mgmt" accept
        '';
      };
      guest = {
        enable = true;
        gatewayMac = "8e:9d:a2:87:aa:76";
        firewall.extraForwardRules = ''
          iifname "vlan-guest" oifname "veth-guest" accept
        '';
      };
      iot = {
        enable = false;
      };
    };
    openssh = {
      enable = true;
      namespace = true;
    };
  };

  networking = {
    resolvconf.enable = true;
    nftables.tables."nixos-nat" = {
      family = "ip";
      content = ''
        chain postrouting {
          type nat hook postrouting priority srcnat; policy accept;
          oifname "wan0" iifname "vrf-transit" counter masquerade
        }
      '';
    };
    firewall = {
      allowPing = false;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      checkReversePath = "strict";
      extraForwardRules = ''
        iifname "vrf-transit" oifname "wan0" accept
      '';
      filterForward = true;
      interfaces = {
        "wan0" = {
          allowedTCPPorts = [ ];
          allowedUDPPorts = [ ];
        };
      };
      logRefusedConnections = false;
      logRefusedPackets = false;
      logReversePathDrops = true;
    };
  };

  services = {
    nscd.enable = false;
    pipewire.enable = false;
    resolved.enable = false;
  };
  system.nssModules = lib.mkForce [ ];

  systemd.network = {
    netdevs = {
      "10-vrf-iot" = {
        netdevConfig = {
          Kind = "vrf";
          Name = "vrf-iot";
        };
        vrfConfig.Table = 30;
      };
      "10-vrf-transit" = {
        netdevConfig = {
          Kind = "vrf";
          Name = "vrf-transit";
        };
        vrfConfig.Table = 100;
      };
      "10-veth-mgmt" = {
        netdevConfig = {
          Kind = "veth";
          Name = "veth-mgmt";
        };
        peerConfig = {
          Name = "veth-tr-mgmt";
        };
      };
      "10-veth-guest" = {
        netdevConfig = {
          Kind = "veth";
          Name = "veth-guest";
        };
        peerConfig = {
          Name = "veth-tr-guest";
        };
      };
      "20-br-lan" = {
        netdevConfig = {
          Kind = "bridge";
          MACAddress = config.systemd.network.links."10-lan1".matchConfig.MACAddress;
          Name = "br-lan";
        };
        bridgeConfig = {
          AgeingTimeSec = 60;
          ForwardDelaySec = 2;
          MulticastQuerier = true;
          MulticastSnooping = false;
          VLANFiltering = true;
          DefaultPVID = "none";
        };
      };
      "20-vlan-mgmt" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-mgmt";
        };
        vlanConfig.Id = 10;
      };
      "20-vlan-guest" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-guest";
        };
        vlanConfig.Id = 20;
      };
      "20-vlan-iot" = {
        netdevConfig = {
          Kind = "vlan";
          Name = "vlan-iot";
        };
        vlanConfig.Id = 30;
      };
    };
    networks = {
      "10-vrf-transit" = {
        matchConfig.Name = "vrf-transit";
        networkConfig = {
          IPv4Forwarding = true;
          IPv6Forwarding = true;
          IPv4ReversePathFilter = "strict";
        };
      };
      "25-veth-tr-mgmt" = {
        matchConfig.Name = "veth-tr-mgmt";
        networkConfig = {
          Address = "172.26.10.1/30";
          VRF = "vrf-transit";
          IPv4Forwarding = true;
        };
        linkConfig = {
          MACAddress = "5a:6f:79:3a:33:1a";
          RequiredForOnline = "no";
        };
        routes = [
          {
            Destination = "172.26.10.2/32";
          }
          {
            Destination = net.subnet net.mgmt top;
            Gateway = "172.26.10.2";
          }
        ];
      };
      "25-veth-tr-guest" = {
        matchConfig.Name = "veth-tr-guest";
        networkConfig = {
          Address = "172.26.20.1/30";
          VRF = "vrf-transit";
          IPv4Forwarding = true;
        };
        linkConfig = {
          MACAddress = "8e:9d:a2:87:aa:76";
          RequiredForOnline = false;
        };
        routes = [
          {
            Destination = "172.26.20.2/32";
          }
          {
            Destination = net.subnet net.guest top;
            Gateway = "172.26.20.2";
          }
        ];
      };
      "25-veth-mgmt" = {
        matchConfig.Name = "veth-mgmt";
        linkConfig.Unmanaged = true;
      };
      "25-veth-guest" = {
        matchConfig.Name = "veth-guest";
        linkConfig.Unmanaged = true;
      };
      "30-br-lan-server" = {
        matchConfig.Name = "br-lan";
        networkConfig = {
          DHCP = false;
          IPv6AcceptRA = false;
          KeepConfiguration = "static";
          LinkLocalAddressing = false;
        };
        vlan = [
          "vlan-mgmt"
          "vlan-guest"
          "vlan-iot"
        ];
        bridgeVLANs = [
          { VLAN = 10; }
          { VLAN = 20; }
          { VLAN = 30; }
        ];
      };
      "35-br-lan-strict" = {
        matchConfig.Name = "lan[1-3]";
        networkConfig.Bridge = "br-lan";
        bridgeVLANs = [
          { VLAN = 10; }
          { VLAN = 20; }
          { VLAN = 30; }
        ];
      };
      "35-br-lan-wifi-mgmt" = {
        matchConfig.Name = "wlan_24 wlan_5";
        bridgeVLANs = [
          {
            PVID = 10;
            EgressUntagged = 10;
          }
        ];
        networkConfig = {
          Bridge = "br-lan";
        };
      };
      "35-br-lan-wifi-guest" = {
        matchConfig.Name = "wlan_24_guest wlan_5_guest";
        bridgeVLANs = [
          {
            PVID = 20;
            EgressUntagged = 20;
          }
        ];
        networkConfig = {
          Bridge = "br-lan";
        };
      };
      "40-vlan-mgmt-server" = {
        matchConfig.Name = "vlan-mgmt";
        linkConfig.Unmanaged = true;
      };
      "40-vlan-guest-server" = {
        matchConfig.Name = "vlan-guest";
        linkConfig.Unmanaged = true;
      };
      "40-vlan-iot-server" = {
        matchConfig.Name = "vlan-iot";
        linkConfig.Unmanaged = true;
      };
      "40-wan" = {
        matchConfig.Name = "wan0";
        networkConfig = {
          DHCP = true;
          DHCPPrefixDelegation = true;
          IPv4Forwarding = true;
          IPv4ReversePathFilter = "strict";
          IPv6AcceptRA = true;
          IPv6Forwarding = true;
          IPv6SendRA = false;
          VRF = "vrf-transit";
        };
        dhcpV4Config = {
          RouteMetric = 10;
          UseDNS = false;
          UseHostname = false;
          UseRoutes = true;
        };
        dhcpV6Config = {
          PrefixDelegationHint = "::/56";
          UseDNS = false;
        };
      };
    };
  };
}
