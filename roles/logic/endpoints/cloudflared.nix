{
  lib,
  config,
  ...
}:
{
  config = lib.mkIf config.lab.endpoints.cloudflared.enable {
    sops = {
      secrets = {
        "cloudflare-account-tag".key = "cloudflare/account-tag";
        "cloudflare-tunnel-id".key = "cloudflare/tunnel-id";
        "cloudflare-tunnel-secret".key = "cloudflare/tunnel-secret";
      };
      templates = {
        "cloudflare-tunnel-config" = {
          content = builtins.toJSON {
            AccountTag = config.sops.placeholder."cloudflare-account-tag";
            TunnelSecret = config.sops.placeholder."cloudflare-tunnel-secret";
            TunnelID = config.sops.placeholder."cloudflare-tunnel-id";
          };
        };
      };
    };
    services.cloudflared = {
      enable = true;
      tunnels = {
        "${config.networking.domain}" = {
          credentialsFile = config.sops.templates."cloudflare-tunnel-config".path;
          ingress = lib.listToAttrs (
            map (v: lib.nameValuePair v.hostname v.ingress) (lib.attrValues config.lab.endpoints.hosts)
          );
          default = "http_status:503";
        };
      };
    };
  };
}
