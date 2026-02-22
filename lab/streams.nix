{
  pkgs,
  lib,
  config,
  relations,
  ...
}:
let
  rel = relations.streams;
in
{
  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      (lib.mkIf rel.isClient {
        home-manager.users.${config.lab.mainUser} = {
          wayland.windowManager.hyprland = {
            settings = {
              bind = [
                "$mod_apps, s, exec, $quickterm ${lib.getExe pkgs.streamshower} -a https://streams.${config.networking.domain}/stream-data"
              ];
            };
          };
        };
      })
      (lib.mkIf rel.isHost {
        lab.endpoints.hosts = {
          "streams".caddy.extraConfig = ''
            reverse_proxy 127.0.0.1:${toString config.services.streamserver.port}
          '';
        };
        sops = {
          secrets = {
            "streamserver-client-id".key = "streamserver/client-id";
            "streamserver-client-secret".key = "streamserver/client-secret";
          };
          templates = {
            "streamserver-env" = {
              content = ''
                USER_NAME=hoppenr
                CLIENT_ID=${config.sops.placeholder."streamserver-client-id"}
                CLIENT_SECRET=${config.sops.placeholder."streamserver-client-secret"}
              '';
            };
          };
        };
        services.streamserver = {
          enable = true;
          port = 8181;
          domain = config.networking.domain;
          environmentFile = config.sops.templates."streamserver-env".path;
        };
      })
    ]
  );
}
