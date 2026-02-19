{
  lib,
  config,
  ...
}:
{
  imports = [
    ./caddy.nix
    ./cloudflared.nix
  ];
  options.lab = {
    endpoints = {
      caddy.enable = lib.mkEnableOption "Caddy generation for endpoints";
      cloudflared.enable = lib.mkEnableOption "Cloudflare tunnel generation for endpoints";
      hosts = lib.mkOption {
        default = { };
        type = lib.types.attrsOf (
          lib.types.submodule (
            { name, ... }@sub:
            {
              options = {
                hostname = lib.mkOption {
                  type = lib.types.str;
                  default = if name == "@" then config.lab.domainName else "${name}.${config.lab.domainName}";
                };
                ingress = lib.mkOption {
                  type = lib.types.either lib.types.str (
                    lib.types.submodule {
                      options = {
                        service = lib.mkOption {
                          type = lib.types.str;
                          description = "e.g. https://localhost:443";
                        };
                        originRequest = {
                          originServerName = lib.mkOption {
                            type = lib.types.str;
                            description = "e.g. subdomain.example.com";
                          };
                        };
                      };
                    }
                  );
                  default = {
                    service = "https://localhost:443";
                    originRequest.originServerName = sub.config.hostname;
                  };
                };
                caddy = {
                  enable = lib.mkOption {
                    type = lib.types.bool;
                    default = true;
                  };
                  extraConfig = lib.mkOption {
                    type = lib.types.str;
                  };
                };
              };
            }
          )
        );
      };
    };
  };
}
