{
  pkgs,
  lib,
  config,
  relations,
  writeZsh,
  ...
}:
let
  rel = relations.streams;
in
{
  config = lib.mkIf rel.isActive (
    lib.mkMerge [
      {
        sops = {
          secrets = {
            "streamserver-basic-auth-pass".key = "streamserver/basic-auth-pass";
          };
        };
      }
      (lib.mkIf rel.isClient {
        assertions = [
          {
            assertion = config.programs.hyprland.enable;
            message = "Expected hyprland for streamshower keybind";
          }
        ];
        sops = {
          templates = {
            "streamshower-env" = {
              content = ''
                STREAMS_BASIC_AUTH_PASS=${config.sops.placeholder."streamserver-basic-auth-pass"}
                STREAMS_BASIC_AUTH_USER=hoppenr
              '';
              owner = config.lab.mainUser;
            };
          };
        };
        home-manager.users.${config.lab.mainUser} = {
          wayland.windowManager.hyprland = {
            settings = {
              bind = [
                "$mod_apps, s, exec, $terminal start -- ${
                  writeZsh "streamshower-wrapped" /* zsh */ ''
                    declare -a env_vars
                    env_vars=("''${(f)$(<"${config.sops.templates."streamshower-env".path}")}")
                    export "''${env_vars[@]}"
                    exec ${lib.getExe pkgs.streamshower} -a "https://streams.${config.networking.domain}/stream-data"
                  ''
                }"
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
                CLIENT_ID=${config.sops.placeholder."streamserver-client-id"}
                CLIENT_SECRET=${config.sops.placeholder."streamserver-client-secret"}
                STREAMS_BASIC_AUTH_PASS=${config.sops.placeholder."streamserver-basic-auth-pass"}
                USER_NAME=hoppenr
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
        systemd.services = {
          streamserver = {
            restartTriggers = [
              config.sops.templates."streamserver-env".path
            ];
          };
        };
      })
    ]
  );
}
