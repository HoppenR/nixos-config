{
  lib,
  config,
  pkgs,
  net,
  ...
}:
let
  enabledCaddyEndpoints = lib.filterAttrs (_: v: v.caddy.enable) config.lab.endpoints.hosts;
in
{
  options.lab.endpoints = {
    caddy = {
      enable = lib.mkEnableOption "Caddy generation for endpoints";
    };
  };
  config = lib.mkIf config.lab.endpoints.caddy.enable {
    networking.firewall.interfaces."vlan-mgmt".allowedTCPPorts = [
      80
      443
    ];
    sops = {
      secrets = {
        "cloudflare-api-token".key = "cloudflare/api-token";
      };
      templates = {
        "caddy-dns-config" = {
          owner = config.users.users.caddy.name;
          inherit (config.users.users.caddy) group;
          content = ''
            tls {
              dns cloudflare ${config.sops.placeholder.cloudflare-api-token}
              resolvers 1.1.1.1
            }
          '';
        };
      };
    };
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.4" ];
        hash = "sha256-J0HWjCPoOoARAxDpG2bS9c0x5Wv4Q23qWZbTjd8nW84=";
      };
      globalConfig =
        let
          trustedProxies = [
            "127.0.0.1"
            "::1"
            (net.ip net.mgmt config.networking.hostName)
            (net.ip6 net.mgmt config.networking.hostName)
          ];
        in
        ''
          servers {
            trusted_proxies static ${lib.concatStringsSep " " trustedProxies}
            client_ip_headers CF-Connecting-IP X-Forwarded-For
            strict_sni_host on
          }
        '';
      extraConfig = ''
        :443, :80 {
          abort
        }
      '';
      virtualHosts = lib.listToAttrs (
        map (
          v:
          lib.nameValuePair v.hostname {
            extraConfig = ''
              import ${config.sops.templates."caddy-dns-config".path}
              bind ${net.ip net.mgmt config.networking.hostName} ${net.ip6 net.mgmt config.networking.hostName} ${lib.optionalString v.cloudflare.enable "127.0.0.1 ::1"}
              header {
                Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
                defer
              }
              ${v.caddy.extraConfig}
            '';
          }
        ) (lib.attrValues enabledCaddyEndpoints)
      );
    };
  };
}
