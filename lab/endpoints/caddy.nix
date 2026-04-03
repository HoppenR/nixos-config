{
  lib,
  config,
  pkgs,
  inventory,
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
    networking.firewall.allowedTCPPorts = [
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
            }
          '';
        };
      };
    };
    services.caddy = {
      enable = true;
      package = pkgs.caddy.withPlugins {
        plugins = [ "github.com/caddy-dns/cloudflare@v0.2.3" ];
        hash = "sha256-20o+14cn/eeLuf1c8uGE1ODRZGC0oxocaIVlv4tFSvA=";
      };
      globalConfig =
        let
          trustedProxies = [
            "127.0.0.1"
            "::1"
            inventory.${config.networking.hostName}.ipv4
            inventory.${config.networking.hostName}.ipv6
          ];
        in
        ''
          servers {
            trusted_proxies static ${lib.concatStringsSep " " trustedProxies}
            client_ip_headers CF-Connecting-IP X-Forwarded-For
          }
        '';
      virtualHosts = lib.listToAttrs (
        map (
          v:
          lib.nameValuePair v.hostname {
            extraConfig = ''
              import ${config.sops.templates."caddy-dns-config".path}
              # bind 127.0.0.1 ::1
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
