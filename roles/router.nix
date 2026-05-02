{
  config,
  lib,
  pkgs,
  inventory,
  topology,
  net,
  writeZsh,
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
    etc = {
      "netns/ns-mgmt/hosts".text = ''
        127.0.0.1 localhost
        ::1 localhost
        127.0.0.2 ${config.networking.hostName}.${config.networking.domain} ${config.networking.hostName}
      ''
      + (lib.concatMapStrings (hostName: ''
        ${net.ip net.mgmt hostName} ${hostName}.${config.networking.domain}
        ${net.ip6 net.mgmt hostName} ${hostName}.${config.networking.domain}
      '') (lib.attrNames inventory));
      "netns/ns-guest/hosts".text = ''
        127.0.0.1 localhost
        ::1 localhost
        127.0.0.2 ${config.networking.hostName}
      '';
      "netns/ns-mgmt/resolv.conf".text = ''
        nameserver 127.0.0.1
        nameserver ::1
        nameserver ${net.ip net.mgmt config.networking.hostName}
        nameserver ${net.ip6 net.mgmt config.networking.hostName}
        search ${config.networking.domain}
        options edns0 trust-ad
      '';
      "netns/ns-guest/resolv.conf".text = ''
        nameserver 127.0.0.1
        nameserver ::1
        nameserver ${net.ip net.guest config.networking.hostName}
        nameserver ${net.ip6 net.guest config.networking.hostName}
        options edns0 trust-ad
      '';
    };
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

  system.nssModules = lib.mkForce [ ];

  services = {
    nscd.enable = false;
    dnsmasq = {
      enable = true;
      settings = {
        bind-interfaces = true;
        bogus-priv = true;
        # domain = config.networking.domain;
        domain-needed = true;
        enable-ra = true;
        expand-hosts = true;
        interface = "vlan-guest";
        no-hosts = true;
        no-resolv = true;
        dhcp-host = lib.flatten (
          lib.mapAttrsToList (
            hostName: hostData:
            lib.optional (
              hostData ? mac && hostData != machine
            ) "${hostData.mac},${net.ip net.guest hostName},${hostName}"
          ) inventory
        );
        dhcp-option = [
          "option:router,${net.ip net.guest config.networking.hostName}"
          "option:dns-server,${net.ip net.guest config.networking.hostName}"
          "option:ntp-server,162.159.200.1" # time.cloudflare.com
          "option6:dns-server,[${net.ip6 net.guest config.networking.hostName}]"
        ];
        dhcp-range = [
          "${top.ipBase}.${toString net.guest}.127,${top.ipBase}.${toString net.guest}.254,24h"
          "::,constructor:vlan-guest,ra-stateless,64"
        ];
        server = [
          "9.9.9.9"
          "149.112.112.112"
        ];
      };
    };
    chrony = {
      enable = true;
      enableNTS = true;
      extraConfig = ''
        allow ${net.subnet net.mgmt top}
        allow ${net.subnet6 net.mgmt top}
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
    resolved.enable = false;
  };

  systemd = {
    targets = {
      multi-user.wants = [
        "setup-network@mgmt.service"
        "setup-network@guest.service"
        # "setup-network@iot.service"
        "nftables-ns@mgmt.service"
        "nftables-ns@guest.service"
        # "nftables-ns@iot.service"
      ];
    };
    services = {
      dnsmasq = {
        after = [ "setup-network@guest.service" ];
        requires = [ "setup-network@guest.service" ];
        serviceConfig = {
          BindPaths = [
            "/etc/netns/ns-guest/hosts:/etc/hosts"
            "/etc/netns/ns-guest/resolv.conf:/etc/resolv.conf"
          ];
          NetworkNamespacePath = "/run/netns/ns-guest";
        };
      };
      chronyd = {
        after = [ "setup-network@mgmt.service" ];
        requires = [ "setup-network@mgmt.service" ];
        serviceConfig = {
          BindPaths = [
            "/etc/netns/ns-mgmt/hosts:/etc/hosts"
            "/etc/netns/ns-mgmt/resolv.conf:/etc/resolv.conf"
          ];
          NetworkNamespacePath = "/run/netns/ns-mgmt";
        };
      };
      sshd = {
        after = [ "setup-network@mgmt.service" ];
        requires = [ "setup-network@mgmt.service" ];
        serviceConfig = {
          BindPaths = [
            "/etc/netns/ns-mgmt/hosts:/etc/hosts"
            "/etc/netns/ns-mgmt/resolv.conf:/etc/resolv.conf"
          ];
          NetworkNamespacePath = "/run/netns/ns-mgmt";
        };
      };

      "netns@" = {
        before = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.iproute2}/bin/ip netns add ns-%i";
          ExecStop = "${pkgs.iproute2}/bin/ip netns del ns-%i";
        };
      };
      "move-netdev@" = {
        after = [ "netns@%i.service" ];
        requires = [ "netns@%i.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${
            writeZsh "move-netdev.zsh" /* zsh */ ''
              for i in {1..50}; do
                if ${pkgs.iproute2}/bin/ip link show vlan-$1 >/dev/null 2>&1; then
                  ${pkgs.iproute2}/bin/ip link set vlan-$1 netns ns-$1
                  break
                fi
                sleep 0.1
              done
              for i in {1..50}; do
                if ${pkgs.iproute2}/bin/ip link show veth-$1 >/dev/null 2>&1; then
                  ${pkgs.iproute2}/bin/ip link set veth-$1 netns ns-$1
                  break
                fi
                sleep 0.1
              done
            ''
          } %i";
        };
      };
      "setup-network@" = {
        after = [ "move-netdev@%i.service" ];
        requires = [ "move-netdev@%i.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          NetworkNamespacePath = "/run/netns/ns-%i";
          ExecStart =
            let
              mkSetupNetworkScript =
                name: data:
                writeZsh "setup-network-${name}" /* zsh */ ''
                  sysctl -w net.ipv4.ip_forward=1
                  ip link set lo up
                  ip link set vlan-${name} up
                  ip addr replace ${net.ip net.${name} config.networking.hostName}/24 dev vlan-${name}
                  ip addr replace ${net.ip6 net.${name} config.networking.hostName}/64 dev vlan-${name}
                  ip neighbor replace 172.26.${toString net.${name}}.1 lladdr "${data.mac}" dev veth-${name}
                  sysctl -w net.ipv4.conf.vlan-${name}.forwarding=1
                  sysctl -w net.ipv4.conf.vlan-${name}.rp_filter=1
                  ip link set veth-${name} up
                  ip addr replace 172.26.${toString net.${name}}.2/30 dev veth-${name}
                  ip route replace default via 172.26.${toString net.${name}}.1
                  sysctl -w net.ipv4.conf.veth-${name}.forwarding=1
                  sysctl -w net.ipv4.conf.veth-${name}.rp_filter=1
                '';
            in
            "${
              writeZsh "move-netdev.zsh" /* zsh */ ''
                case "$1" in
                  mgmt) exec ${mkSetupNetworkScript "mgmt" { mac = "5a:6f:79:3a:33:1a"; }} ;;
                  guest) exec ${mkSetupNetworkScript "guest" { mac = "8e:9d:a2:87:aa:76"; }} ;;
                esac
              ''
            } %i";
        };
      };
      "nftables-ns@" = {
        description = "nftables firewall for namespace %i";
        bindsTo = [ "netns@%i.service" ];
        after = [ "netns@%i.service" ];
        before = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          NetworkNamespacePath = "/run/netns/ns-%i";
          ExecStart =
            let
              mkNftRules =
                name:
                {
                  tcp ? [ ],
                  udp ? [ ],
                  extraInputRules ? "",
                  extraForwardRules ? "",
                  extraReversePathFilterRules ? "",
                }:
                pkgs.writeText "nftables-${name}.conf" ''
                  flush ruleset
                  table inet nixos-fw {
                    chain rpfilter {
                      type filter hook prerouting priority mangle + 10; policy drop;
                      meta nfproto ipv4 udp sport . udp dport { 68 . 67, 67 . 68 } accept comment "DHCPv4 client/server"
                      fib saddr . mark . iif oif exists accept
                      jump rpfilter-allow
                      log level info prefix "rpfilter drop: "
                    }
                    chain rpfilter-allow {
                      ${extraReversePathFilterRules}
                    }
                    chain input {
                      type filter hook input priority filter; policy drop;
                      iifname "lo" accept
                      icmpv6 type echo-reply accept
                      ct state vmap { invalid : drop, established : accept, related : accept, new : jump input-allow, untracked : jump input-allow }
                    }
                    chain input-allow {
                      icmpv6 type != { nd-redirect, 139 } accept
                      ip6 daddr fe80::/64 udp dport 546 accept comment "DHCPv6 client"
                      ${
                        if tcp != [ ] then "tcp dport { ${lib.concatStringsSep ", " (map toString tcp)} } accept" else ""
                      }
                      ${
                        if udp != [ ] then "udp dport { ${lib.concatStringsSep ", " (map toString udp)} } accept" else ""
                      }
                      ${extraInputRules}
                    }
                    chain forward {
                      type filter hook forward priority filter; policy drop;
                      ct state vmap { established : accept, related : accept, new : jump forward-allow, untracked : jump forward-allow }
                    }
                    chain forward-allow {
                      icmpv6 type != { router-renumbering, 139 } accept
                      ct status dnat accept comment "allow port forward"
                      ${extraForwardRules}
                    }
                  }
                '';
              rules = {
                mgmt = {
                  tcp = [
                    22 # SSH
                    53 # DNS
                  ];
                  udp = [
                    53
                    67 # DHCPv4
                    123 # NTP
                    323 # Chrony control
                    547 # DHCPv6
                  ];
                  extraInputRules = ''
                    ip saddr ${net.ip net.mgmt top.server} tcp dport 443 accept
                    ip6 saddr ${net.ip6 net.mgmt top.server} tcp dport 443 accept
                  '';
                  extraForwardRules = ''
                    iifname "vlan-mgmt" oifname "veth-mgmt" accept
                  '';
                };
                guest = {
                  tcp = [
                    53 # DNS
                  ];
                  udp = [
                    53 # DNS
                    67 # DHCPv4
                    547 # DHCPv6
                  ];
                  extraForwardRules = ''
                    iifname "vlan-guest" oifname "veth-guest" accept
                  '';
                  extraReversePathFilterRules = "";
                };
              };
            in
            "${writeZsh "load-nft-ns" ''
              case "$1" in
                mgmt)  ${pkgs.nftables}/bin/nft -f ${mkNftRules "mgmt" rules.mgmt} ;;
                guest) ${pkgs.nftables}/bin/nft -f ${mkNftRules "guest" rules.guest} ;;
              esac
            ''} %i";
          ExecStop = "${pkgs.nftables}/bin/nft flush ruleset";
        };
      };
    };
    network = {
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
  };
}
