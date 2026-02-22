{
  lib,
  config,
  pkgs,
  ...
}:
let
  enabledCaddyEndpoints = lib.filterAttrs (_: v: v.caddy.enable) config.lab.endpoints.hosts;
in
{
  config = lib.mkIf config.lab.endpoints.caddy.enable {
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
        hash = "sha256-bJO2RIa6hYsoVl3y2L86EM34Dfkm2tlcEsXn2+COgzo=";
      };
      virtualHosts = lib.listToAttrs (
        map (
          v:
          lib.nameValuePair v.hostname {
            extraConfig = ''
              import ${config.sops.templates."caddy-dns-config".path}
              ${v.caddy.extraConfig}
            '';
          }
        ) (lib.attrValues enabledCaddyEndpoints)
      );
    };
  };
}
