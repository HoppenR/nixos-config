{
  inputs,
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
  mgmtSubnet = "${top.ipBase}.${toString net.mgmt}.0/24";
  mgmtv6Subnet = "${top.ip6Base}:${toString net.mgmt}::/64";
  guestSubnet = "${top.ipBase}.${toString net.guest}.0/24";
  guestv6Subnet = "${top.ip6Base}:${toString net.guest}::/64";
  networkServer = topology.${machine.topology}.server;
  endpoints = inputs.self.nixosConfigurations.${networkServer}.config.lab.endpoints.hosts;
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

    "net.ipv4.conf.veth-tr-host.accept_local" = 1;
    "net.ipv4.conf.vrf-transit.accept_local" = 1;
    "net.ipv4.ip_nonlocal_bind" = 1;
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
    openssh = {
      enable = true;
    };
    greetd = {
      enable = false;
    };
  };

  sops.secrets = {
    "wifi-mgmt-password".key = "wifi/mgmt-password";
    "wifi-guest-password".key = "wifi/guest-password";
  };

  networking = {
    hosts = lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList (hostName: _: {
        "${net.ip net.mgmt hostName}" = [ "${hostName}.${config.networking.domain}" ];
        "${net.ip6 net.mgmt hostName}" = [ "${hostName}.${config.networking.domain}" ];
      }) inventory
    );
    nftables.tables."nixos-nat" = {
      family = "ip";
      content = ''
        chain prerouting {
          type filter hook prerouting priority raw; policy accept;
          iifname { "veth-tr-host", "veth-tr-mgmt", "veth-tr-guest" } counter ct zone set 1
          iifname "wan0" counter ct zone set 1
        }
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
        iifname "veth-tr-mgmt" oifname "vrf-transit" accept
        iifname "veth-tr-guest" oifname "vrf-transit" accept
        iifname "veth-tr-host" oifname "vrf-transit" accept
        iifname "vrf-transit" oifname "wan0" accept
        iifname "vrf-mgmt" oifname "veth-mgmt" accept
        iifname "vrf-guest" oifname "veth-guest" accept
      '';
      extraReversePathFilterRules = ''
        iifname "veth-tr-host" accept
        iifname "vrf-transit" accept
      '';
      filterForward = true;
      interfaces = {
        "vrf-mgmt" = {
          allowedTCPPorts = [
            22
            53
            3000
            5353
          ];
          allowedUDPPorts = [
            53
            67
            123
            323
            5353
          ];
        };
        "vrf-guest" = {
          allowedTCPPorts = [
            53
            5353
          ];
          allowedUDPPorts = [
            53
            67
            123
            323
            5353
          ];
        };
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
    adguardhome = {
      enable = true;
      port = 3000;
      mutableSettings = false;
      openFirewall = false;
      host = net.ip net.mgmt config.networking.hostName;
      settings = {
        # TODO: set up webgui-interface over https via caddy
        #       should set up caddy to serve only over 192.168.10.0/24
        #       for internal endpoints
        auth_attempts = 5;
        block_auth_min = 15;
        users = [
          {
            name = "admin";
            password = "$2b$05$/XS4VgbMhE6PUWQhoa7JPuXenSCDKZrLFX0twny4.bCXYoGduN63W";
          }
        ];
        dns = {
          allowed_clients = [
            "127.0.0.1"
            "::1"
            mgmtSubnet
            mgmtv6Subnet
          ];
          bind_hosts = [
            "127.0.0.1"
            "::1"
            (net.ip net.mgmt config.networking.hostName)
            (net.ip6 net.mgmt config.networking.hostName)
          ];
          bootstrap_dns = [ "9.9.9.9" ];
          cache_optimistic = true;
          clients = {
            runtime_sources = {
              hosts = true;
              rdns = true;
            };
          };
          enable_dnssec = true;
          hostsfile_enabled = true;
          # TODO: fix not being able to access 127.0.0.53:53 from vrf-mgmt
          #       -> also enable use_private_ptr_resolvers
          # local_ptr_upstreams = [ "127.0.0.53:53" ];
          use_private_ptr_resolvers = false;
          port = 53;
          private_networks = [
            mgmtSubnet
            mgmtv6Subnet
          ];
          upstream_dns = [ "https://dns.quad9.net/dns-query" ];
        };
        filtering = {
          rewrites = (
            # Prevent leaking the 127.0.0.2 entry in /etc/hosts
            [
              {
                domain = "${config.networking.hostName}.${config.networking.domain}";
                answer = net.ip net.mgmt config.networking.hostName;
                enabled = true;
              }
              {
                domain = "${config.networking.hostName}.${config.networking.domain}";
                answer = net.ip6 net.mgmt config.networking.hostName;
                enabled = true;
              }
              {
                domain = "${config.networking.hostName}";
                answer = net.ip net.mgmt config.networking.hostName;
                enabled = true;
              }
              {
                domain = "${config.networking.hostName}";
                answer = net.ip6 net.mgmt config.networking.hostName;
                enabled = true;
              }
            ]
            ++ (lib.flatten (
              lib.mapAttrsToList (name: info: [
                {
                  domain = info.hostname;
                  answer = net.ip net.mgmt networkServer;
                  enabled = true;
                }
                {
                  domain = info.hostname;
                  answer = net.ip6 net.mgmt networkServer;
                  enabled = true;
                }
              ]) endpoints
            ))
          );
        };
      };
    };
    chrony = {
      # TODO: figure out how to get chrony to serve vrf-mgmt
      enable = true;
      enableNTS = true;
      extraConfig = ''
        allow ${mgmtSubnet}
        allow ${mgmtv6Subnet}
        bindaddress ${net.ip net.mgmt config.networking.hostName}
        bindaddress ${net.ip6 net.mgmt config.networking.hostName}
      '';
      servers = [
        "nts.netnod.se"
        "nts.ntp.se"
      ];
    };
    hostapd = {
      enable = true;
      radios = {
        wlan_24 = {
          band = "2g";
          channel = 0;
          countryCode = "SE";
          networks = {
            wlan_24 = {
              ssid = "asgard_24";
              bssid = "00:0a:52:0e:e4:14";
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-mgmt-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-mgmt-password".path;
              };
              settings = {
                bridge = "br-lan";
                chanlist = "1 6 11 13";
                hw_mode = "g";
                ieee80211ax = 1;
                ieee80211w = 1;
              };
            };
            wlan_24_guest = {
              ssid = "midgard_24";
              # TODO: generate this based on "10-wlan-24".matchConfig.MACAddress
              #       editing the 2nd character: 00, 02, 06, 0A, then 0E
              #       (programmatically)
              bssid = "02:0a:52:0e:e4:14";
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-guest-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-guest-password".path;
              };
              settings = {
                bridge = "br-lan";
                chanlist = "1 6 11 13";
                hw_mode = "g";
                ieee80211ax = 1;
                ieee80211w = 1;
              };
            };
          };
          wifi6 = {
            enable = true;
          };
        };
        wlan_5 = {
          band = "5g";
          channel = 0;
          countryCode = "SE";
          networks = {
            wlan_5 = {
              ssid = "asgard_5";
              bssid = "00:0a:52:0e:e4:15";
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-mgmt-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-mgmt-password".path;
              };
              settings = {
                bridge = "br-lan";
                chanlist = "36 40 44 48";
                hw_mode = "a";
                ieee80211ac = true;
                ieee80211ax = true;
                ieee80211d = true;
                ieee80211h = true;
                ieee80211n = true;
                wmm_enabled = 1;
              };
            };
            wlan_5_guest = {
              ssid = "midgard_5";
              # TODO: generate this based on "10-wlan-24".matchConfig.MACAddress
              #       editing the 2nd character: 00, 02, 06, 0A, then 0E
              #       (programmatically)
              bssid = "02:0a:52:0e:e4:15";
              authentication = {
                mode = "wpa3-sae-transition";
                saePasswordsFile = config.sops.secrets."wifi-guest-password".path;
                wpaPasswordFile = config.sops.secrets."wifi-guest-password".path;
              };
              settings = {
                bridge = "br-lan";
                chanlist = "36 40 44 48";
                hw_mode = "a";
                ieee80211ac = true;
                ieee80211ax = true;
                ieee80211d = true;
                ieee80211h = true;
                ieee80211n = true;
                wmm_enabled = 1;
              };
            };
          };
          wifi5 = {
            enable = true;
            operatingChannelWidth = "80";
            capabilities = [
              "MAX-MPDU-11454"
              "SHORT-GI-80"
              "TX-STBC-2BY1"
              "RX-STBC-1"
              "SU-BEAMFORMER"
              "SU-BEAMFORMEE"
              "MU-BEAMFORMER"
            ];
          };
          wifi6 = {
            enable = true;
            multiUserBeamformer = true;
            singleUserBeamformee = true;
            singleUserBeamformer = true;
          };
        };
      };
    };
    openssh = {
      openFirewall = false;
    };
    pipewire.enable = false;
    resolved = {
      settings.Resolve = {
        Cache = true;
        DNS = [
          "127.0.0.1"
          "::1"
        ];
        FallbackDNS = [ "" ];
        Domains = [
          "~."
          "~${config.networking.domain}"
        ];
        DNSStubListener = true;
      };
    };
  };

  systemd = {
    services = {
      adguardhome = {
        after = [ "sys-subsystem-net-devices-vrf\\x2dmgmt.device" ];
        bindsTo = [ "sys-subsystem-net-devices-vrf\\x2dmgmt.device" ];
        serviceConfig.BindNetworkInterface = "vrf-mgmt";
      };
      chrony = {
        after = [ "sys-subsystem-net-devices-vrf\\x2dmgmt.device" ];
        bindsTo = [ "sys-subsystem-net-devices-vrf\\x2dmgmt.device" ];
        serviceConfig.BindNetworkInterface = "vrf-mgmt";
      };
      sshd = {
        after = [ "sys-subsystem-net-devices-vrf\\x2dmgmt.device" ];
        bindsTo = [ "sys-subsystem-net-devices-vrf\\x2dmgmt.device" ];
        serviceConfig.BindNetworkInterface = "vrf-mgmt";
      };
    };
    network = {
      netdevs = {
        "10-vrf-mgmt" = {
          netdevConfig = {
            Kind = "vrf";
            Name = "vrf-mgmt";
          };
          vrfConfig.Table = 10;
        };
        "10-vrf-guest" = {
          netdevConfig = {
            Kind = "vrf";
            Name = "vrf-guest";
          };
          vrfConfig.Table = 20;
        };
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
        "10-veth-host" = {
          netdevConfig = {
            Kind = "veth";
            Name = "veth-host";
          };
          peerConfig = {
            Name = "veth-tr-host";
          };
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
        "10-vrf-mgmt" = {
          matchConfig.Name = "vrf-mgmt";
          address = [
            "127.0.0.1/8"
            "::1/128"
          ];
          # TODO: add ipv6 local routes?
          routes = [
            {
              Destination = "127.0.0.1";
              Type = "local";
              Table = 10;
            }
            {
              Destination = "192.168.10.1";
              Type = "local";
              Table = 10;
            }
          ];
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
          };
        };
        "10-vrf-guest" = {
          matchConfig.Name = "vrf-guest";
          address = [
            "127.0.0.1/8"
            "::1/128"
          ];
          # TODO: add routes
          networkConfig = {
            IPv4Forwarding = true;
            IPv6Forwarding = true;
          };
        };
        "25-veth-tr-host" = {
          matchConfig.Name = "veth-tr-host";
          networkConfig = {
            Address = "172.26.0.1/30";
            VRF = "vrf-transit";
            IPv4Forwarding = true;
            IPv4ReversePathFilter = "loose";
          };
          linkConfig = {
            MACAddress = "32:5d:1d:b7:4c:15";
            RequiredForOnline = "no";
          };
          routes = [
            {
              Destination = "172.26.0.2/32";
            }
            {
              Destination = "${top.ipBase}.0.0/24";
              Gateway = "172.26.0.2";
            }
          ];
          neighbors = [
            {
              Address = "172.26.0.2";
              LinkLayerAddress = "9e:1d:b3:f2:b2:1e";
            }
          ];
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
              Destination = mgmtSubnet;
              Gateway = "172.26.10.2";
            }
          ];
          neighbors = [
            {
              Address = "172.26.10.2";
              LinkLayerAddress = "1e:55:ac:e4:d4:7b";
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
          # TODO: add neighbors
          routes = [
            {
              Destination = "172.26.20.2/32";
            }
            {
              Destination = guestSubnet;
              Gateway = "172.26.20.2";
            }
          ];
        };
        "25-veth-host" = {
          matchConfig.Name = "veth-host";
          networkConfig = {
            Address = "172.26.0.2/30";
            IPv4Forwarding = true;
            IPv4ReversePathFilter = "strict";
          };
          linkConfig = {
            MACAddress = "9e:1d:b3:f2:b2:1e";
          };
          neighbors = [
            {
              Address = "172.26.0.1";
              LinkLayerAddress = "32:5d:1d:b7:4c:15";
            }
          ];
          routes = [
            {
              Destination = "0.0.0.0/0";
              Gateway = "172.26.0.1";
            }
          ];
        };
        "25-veth-mgmt" = {
          matchConfig.Name = "veth-mgmt";
          networkConfig = {
            Address = "172.26.10.2/30";
            VRF = "vrf-mgmt";
            IPv4Forwarding = true;
            IPv4ReversePathFilter = "strict";
          };
          linkConfig = {
            MACAddress = "1e:55:ac:e4:d4:7b";
          };
          neighbors = [
            {
              Address = "172.26.10.1";
              LinkLayerAddress = "5a:6f:79:3a:33:1a";
            }
          ];
          routes = [
            {
              Destination = "0.0.0.0/0";
              Gateway = "172.26.10.1";
            }
          ];
        };
        "25-veth-guest" = {
          matchConfig.Name = "veth-guest";
          networkConfig = {
            Address = "172.26.20.2/30";
            VRF = "vrf-guest";
            IPv4Forwarding = true;
            IPv4ReversePathFilter = "strict";
          };
          # TODO: add neighbors
          routes = [
            {
              Destination = "0.0.0.0/0";
              Gateway = "172.26.20.1";
            }
          ];
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
          linkConfig = {
            RequiredForOnline = false;
            Unmanaged = false;
          };
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
          linkConfig = {
            RequiredForOnline = false;
            Unmanaged = false;
          };
          networkConfig = {
            Bridge = "br-lan";
          };
        };
        "40-vlan-mgmt-server" = {
          matchConfig.Name = "vlan-mgmt";
          address = [
            "${net.ip net.mgmt config.networking.hostName}/24"
            "${net.ip6 net.mgmt config.networking.hostName}/64"
          ];
          dhcpPrefixDelegationConfig = {
            Announce = true;
            SubnetId = net.mgmt;
            UplinkInterface = "wan0";
          };
          dhcpServerConfig = {
            DNS = [ (net.ip net.mgmt config.networking.hostName) ];
            EmitDNS = true;
            EmitNTP = true;
            NTP = [
              (net.ip net.mgmt config.networking.hostName)
            ];
            PoolOffset = 127;
            PoolSize = 128;
          };
          dhcpServerStaticLeases = lib.flatten (
            lib.mapAttrsToList (
              hostName: hostData:
              lib.optional (hostData ? mac && hostData != machine) {
                MACAddress = hostData.mac;
                Address = net.ip net.mgmt hostName;
              }
            ) inventory
          );
          domains = [ config.networking.domain ];
          ipv6Prefixes = [ { Prefix = mgmtv6Subnet; } ];
          ipv6SendRAConfig = {
            DNS = [ (net.ip6 net.mgmt config.networking.hostName) ];
            EmitDNS = true;
            Managed = false;
            OtherInformation = true;
          };
          networkConfig = {
            DHCPPrefixDelegation = true;
            DHCPServer = true;
            IPv4Forwarding = true;
            IPv4ReversePathFilter = "strict";
            IPv6AcceptRA = false;
            IPv6Forwarding = true;
            IPv6SendRA = true;
            MulticastDNS = true;
            VRF = "vrf-mgmt";
          };
        };
        "40-vlan-guest-server" = {
          matchConfig.Name = "vlan-guest";
          address = [
            "${net.ip net.guest config.networking.hostName}/24"
            "${net.ip6 net.guest config.networking.hostName}/64"
          ];
          dhcpPrefixDelegationConfig = {
            Announce = true;
            SubnetId = net.guest;
            UplinkInterface = "wan0";
          };
          dhcpServerConfig = {
            DNS = [
              "9.9.9.9"
              "149.112.112.112"
            ];
            EmitDNS = true;
            EmitNTP = true;
            NTP = [ "time.cloudflare.com" ];
            PoolOffset = 127;
            PoolSize = 128;
          };
          ipv6Prefixes = [ { Prefix = guestv6Subnet; } ];
          ipv6SendRAConfig = {
            DNS = [ (net.ip6 net.guest config.networking.hostName) ];
            EmitDNS = true;
            Managed = false;
            OtherInformation = true;
          };
          networkConfig = {
            DHCPPrefixDelegation = true;
            DHCPServer = true;
            # IPMasquerade = "both";
            IPv4Forwarding = true;
            IPv4ReversePathFilter = "strict";
            IPv6AcceptRA = false;
            IPv6Forwarding = true;
            IPv6SendRA = true;
            MulticastDNS = true;
            VRF = "vrf-guest";
          };
        };
        "40-vlan-iot-server" = {
          matchConfig.Name = "vlan-iot";
          # TODO: implement this
        };
        "40-wan" = {
          matchConfig.Name = "wan0";
          networkConfig = {
            DHCP = true;
            DHCPPrefixDelegation = true;
            # IPMasquerade = "both";
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
  };
}
