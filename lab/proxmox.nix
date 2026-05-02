{
  lib,
  config,
  relations,
  net,
  ...
}:
let
  rel = relations.proxmox;
in
{
  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      {
        sops = {
          secrets = {
            "proxmox-certificate" = {
              key = "proxmox/certificate";
              owner = lib.mkIf rel.isClient "caddy";
              group = lib.mkIf rel.isClient "caddy";
            };
          };
        };
      }
      (lib.mkIf rel.isClient {
        lab.endpoints.hosts = {
          "proxmox" = {
            cloudflare.enable = false;
            caddy.extraConfig = ''
              reverse_proxy https://${net.ip net.mgmt rel.host}:8006 {
                transport http {
                  tls_server_name proxmox.${config.networking.domain}
                  tls_trusted_ca_certs ${config.sops.secrets."proxmox-certificate".path}
                }
              }
            '';
          };
        };
      })
    ]
  );
}
