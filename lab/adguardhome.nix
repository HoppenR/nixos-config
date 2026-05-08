{
  inputs,
  lib,
  config,
  relations,
  inventory,
  topology,
  net,
  ...
}:
let
  rel = relations.adguardhome;
  machine = inventory.${config.networking.hostName};
  top = topology.${machine.topology};
  client = lib.head rel.clients;
  endpoints = inputs.self.nixosConfigurations.${client}.config.lab.endpoints.hosts;
in
{
  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      {
        assertions = [
          { assertion = builtins.length rel.clients == 1; }
        ];
        sops.secrets = {
          "adguardhome-certificate" = {
            key = "adguardhome/certificate";
            owner = lib.mkIf rel.isClient "caddy";
            group = lib.mkIf rel.isClient "caddy";
          };
        };
      }
      (lib.mkIf rel.isClient {
        lab.endpoints.hosts = {
          "adguardhome" = {
            cloudflare.enable = false;
            caddy.extraConfig = ''
              reverse_proxy https://[${net.ip6 net.mgmt rel.host}]:443 {
                transport http {
                  tls_server_name adguardhome.${config.networking.domain}
                  tls_trusted_ca_certs ${config.sops.secrets."adguardhome-certificate".path}
                }
              }
            '';
          };
        };
      })
      (lib.mkIf rel.isHost {
        lab.namespaces = {
          mgmt.firewall = {
            tcp = [
              53 # DNS
            ];
            udp = [
              53 # DNS
              67 # DHCPv4
              547 # DHCPv6
            ];
            extraInputRules = ''
              ip6 saddr ${net.ip6 net.mgmt client} tcp dport 443 accept
            '';
          };
        };
        sops.secrets = {
          "adguardhome-key".key = "adguardhome/key";
        };
        systemd.services = {
          adguardhome = {
            after = [ "setup-network@mgmt.service" ];
            requires = [ "setup-network@mgmt.service" ];
            serviceConfig = {
              BindPaths = [
                "/etc/netns/ns-mgmt/hosts:/etc/hosts"
                "/etc/netns/ns-mgmt/resolv.conf:/etc/resolv.conf"
              ];
              NetworkNamespacePath = "/run/netns/ns-mgmt";
              LoadCredential = [
                "cert:${config.sops.secrets."adguardhome-certificate".path}"
                "key:${config.sops.secrets."adguardhome-key".path}"
              ];
            };
          };
        };
        services.adguardhome = {
          enable = true;
          port = 0; # golang: any free available port
          mutableSettings = false;
          openFirewall = false;
          host = "[${net.ip6 net.mgmt config.networking.hostName}]";
          settings = {
            auth_attempts = 5;
            block_auth_min = 15;
            users = [
              {
                name = "admin";
                password = "$2b$05$/XS4VgbMhE6PUWQhoa7JPuXenSCDKZrLFX0twny4.bCXYoGduN63W";
              }
            ];
            dhcp = {
              enabled = true;
              interface_name = "vlan-mgmt";
              local_domain_name = config.networking.domain;
              dhcpv4 = {
                gateway_ip = net.ip net.mgmt config.networking.hostName;
                subnet_mask = "255.255.255.0";
                range_start = "${top.ipBase}.${toString net.mgmt}.127";
                range_end = "${top.ipBase}.${toString net.mgmt}.254";
                lease_duration = 86400;
              };
              dhcpv6 = {
                ra_slaac_only = false;
                ra_allow_slaac = false;
              };
            };
            dns = {
              allowed_clients = [
                "127.0.0.1"
                "::1"
                (net.subnet net.mgmt top)
                (net.subnet6 net.mgmt top)
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
              use_private_ptr_resolvers = false;
              port = 53;
              private_networks = [
                "127.0.0.1/8"
                "::1/128"
                (net.subnet net.mgmt top)
                (net.subnet6 net.mgmt top)
              ];
              upstream_dns = [
                "quic://dns.quad9.net"
                "https://dns.quad9.net/dns-query"
              ];
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
                      answer = net.ip net.mgmt client;
                      enabled = true;
                    }
                    {
                      domain = info.hostname;
                      answer = net.ip6 net.mgmt client;
                      enabled = true;
                    }
                  ]) endpoints
                ))
              );
            };
            tls = {
              enabled = true;
              server_name = "adguardhome.${config.networking.domain}";
              force_https = true;
              certificate_path = "/run/credentials/adguardhome.service/cert";
              private_key_path = "/run/credentials/adguardhome.service/key";
              strict_sni_check = true;
            };
          };
        };
      })
    ]
  );
}
