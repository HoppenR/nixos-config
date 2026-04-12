{
  inputs,
  config,
  lib,
  pkgs,
  inventory,
  topology,
  ...
}:
let
  machine = inventory.${config.networking.hostName};
  subnetParts = lib.take 3 (lib.splitString "." machine.ipv4);
  lanSubnet = "${lib.concatStringsSep "." subnetParts}.0/24";
  lanv6Subnet = "${lib.head (lib.splitString "::" machine.ipv6)}::/64";
  networkServer = topology.${machine.topology}.server;
  endpoints = inputs.self.nixosConfigurations.${networkServer}.config.lab.endpoints.hosts;
in
{
  imports = [
    ./common.nix
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

    "net.ipv4.conf.wan0.accept_ra" = 2;
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
    "wifi-password".key = "wifi/password";
  };

  networking = {
    hosts = lib.foldl' lib.recursiveUpdate { } (
      lib.mapAttrsToList (hostName: hostData: {
        "${hostData.ipv4}" = [ "${hostName}.${config.networking.domain}" ];
        "${hostData.ipv6}" = [ "${hostName}.${config.networking.domain}" ];
      }) inventory
    );
    firewall = {
      # Don't accidentally open it via some service changing configuration
      allowedTCPPorts = lib.mkForce [ ];
      allowedUDPPorts = lib.mkForce [ ];
      checkReversePath = "loose";
      logRefusedConnections = false;
      logRefusedPackets = false;
      logReversePathDrops = true;
      allowPing = true;
      extraForwardRules = ''
        iifname "br-lan" oifname "wan0" accept
      '';
      filterForward = true;
      trustedInterfaces = [ "br-lan" ];
    };
  };

  services = {
    adguardhome = {
      enable = true;
      port = 3000;
      mutableSettings = false;
      openFirewall = false;
      host = machine.ipv4;
      settings = {
        # TODO: set up webgui-interface over https via caddy
        #       should set up caddy to serve only over 192.168.0.0/24
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
            lanSubnet
            lanv6Subnet
          ];
          bind_hosts = [
            "127.0.0.1"
            "::1"
            machine.ipv4
            machine.ipv6
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
          local_ptr_upstreams = [ "127.0.0.53:53" ];
          port = 53;
          private_networks = [
            lanSubnet
            lanv6Subnet
          ];
          upstream_dns = [ "https://dns.quad9.net/dns-query" ];
          use_private_ptr_resolvers = true;
        };
        filtering = {
          rewrites = (
            # Prevent leaking the 127.0.0.2 entry in /etc/hosts
            [
              {
                domain = "${config.networking.hostName}.${config.networking.domain}";
                answer = machine.ipv4;
                enabled = true;
              }
              {
                domain = "${config.networking.hostName}.${config.networking.domain}";
                answer = machine.ipv6;
                enabled = true;
              }
              {
                domain = "${config.networking.hostName}";
                answer = machine.ipv4;
                enabled = true;
              }
              {
                domain = "${config.networking.hostName}";
                answer = machine.ipv6;
                enabled = true;
              }
            ]
            ++ (lib.flatten (
              lib.mapAttrsToList (name: info: [
                {
                  domain = info.hostname;
                  answer = inventory.${networkServer}.ipv4;
                  enabled = true;
                }
                {
                  domain = info.hostname;
                  answer = inventory.${networkServer}.ipv6;
                  enabled = true;
                }
              ]) endpoints
            ))
          );
        };
      };
    };
    chrony = {
      enable = true;
      enableNTS = true;
      extraConfig = ''
        allow ${lanSubnet}
        allow ${lanv6Subnet}
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
          networks.wlan_24 = {
            ssid = "asgard_24";
            authentication = {
              mode = "wpa3-sae-transition";
              saePasswordsFile = config.sops.secrets."wifi-password".path;
              wpaPasswordFile = config.sops.secrets."wifi-password".path;
            };
            settings = {
              chanlist = "1 6 11 13";
              bridge = "br-lan";
              hw_mode = "g";
              ieee80211ax = 1;
              ieee80211w = 1;
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
          networks.wlan_5 = {
            ssid = "asgard_5";
            authentication = {
              mode = "wpa3-sae-transition";
              saePasswordsFile = config.sops.secrets."wifi-password".path;
              wpaPasswordFile = config.sops.secrets."wifi-password".path;
            };
            settings = {
              chanlist = "36 40 44 48";
              bridge = "br-lan";
              hw_mode = "a";
              ieee80211ac = true;
              ieee80211ax = true;
              ieee80211d = true;
              ieee80211h = true;
              ieee80211n = true;
              wmm_enabled = 1;
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
        FallbackDNS = [ ];
        Domains = [
          "~."
          "~${config.networking.domain}"
        ];
        DNSStubListener = true;
        LLMNR = false;
        MulticastDNS = true;
      };
    };
    # unbound = {
    #   enable = true;
    #   settings = {
    #     server = {
    #       interface = [ "127.0.0.1" ];
    #       access-control = [
    #         "127.0.0.0/8 allow"
    #         "${lanSubnet} allow"
    #       ];
    #       private-address = [ lanSubnet ];
    #       harden-glue = "yes";
    #       harden-dnssec-stripped = "yes";
    #       aggressive-nsec = "yes";
    #       use-caps-for-id = "yes";
    #       prefetch = "yes";
    #
    #       num-threads = 4;
    #       msg-cache-slabs = 4;
    #       rrset-cache-slabs = 4;
    #       infra-cache-slabs = 4;
    #       key-cache-slabs = 4;
    #
    #       msg-cache-size = "50m";
    #       rrset-cache-size = "100m";
    #
    #       harden-referral-path = "yes";
    #
    #       hide-identity = "yes";
    #       hide-version = "yes";
    #       qname-minimisation = "yes";
    #     };
    #     forward-zone = [
    #       {
    #         name = ".";
    #         forward-addr = "1.1.1.1@853#cloudflare-dns.com";
    #       }
    #       {
    #         name = "example.org.";
    #         forward-addr = [
    #           "1.1.1.1@853#cloudflare-dns.com"
    #           "1.0.0.1@853#cloudflare-dns.com"
    #         ];
    #       }
    #     ];
    #     remote-control.control-enable = true;
    #   };
    # };
  };

  systemd.network = {
    netdevs = {
      "20-br-lan" = {
        netdevConfig = {
          Kind = "bridge";
          MACAddress = config.systemd.network.links."10-lan1".matchConfig.MACAddress;
          Name = "br-lan";
        };
        bridgeConfig = {
          MulticastSnooping = false;
          MulticastQuerier = true;

          AgeingTimeSec = 60;
          ForwardDelaySec = 2;
          STP = true;
        };
      };
    };
    networks = {
      "30-br-lan-server" = {
        matchConfig.Name = "br-lan";
        address = [
          "${machine.ipv4}/24"
          "${machine.ipv6}/64"
        ];
        networkConfig = {
          ConfigureWithoutCarrier = true;
          DHCPPrefixDelegation = true;
          DHCPServer = true;
          DNS = [
            "127.0.0.1"
            "::1"
          ];
          IPMasquerade = "both";
          IPv4Forwarding = true;
          IPv4ReversePathFilter = "loose";
          IPv6AcceptRA = false;
          IPv6Forwarding = true;
          IPv6SendRA = true;
          MulticastDNS = true;
        };
        dhcpPrefixDelegationConfig = {
          Announce = true;
          SubnetId = "auto";
          UplinkInterface = "wan0";
        };
        domains = [ config.networking.domain ];
        dhcpServerStaticLeases = lib.concatMap (
          hostData:
          lib.optional (hostData ? mac && hostData != machine) {
            MACAddress = hostData.mac;
            Address = hostData.ipv4;
          }
        ) (builtins.attrValues inventory);
        dhcpServerConfig = {
          DNS = [
            machine.ipv4
            machine.ipv6
          ];
          EmitDNS = true;
          EmitNTP = true;
          NTP = [
            machine.ipv4
            machine.ipv6
          ];
          # x.x.x.101 -> x.x.x.200
          PoolOffset = 101;
          PoolSize = 99;
        };
        ipv6Prefixes = [ { Prefix = lanv6Subnet; } ];
        ipv6SendRAConfig = {
          DNS = [ machine.ipv6 ];
          EmitDNS = true;
          Managed = false;
          OtherInformation = true;
        };
      };
      "35-br-lan" = {
        matchConfig.Name = "lan*";
        networkConfig = {
          Bridge = "br-lan";
        };
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
