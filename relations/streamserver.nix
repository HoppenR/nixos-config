{
  pkgs,
  lib,
  config,
  ...
}:
let
  server = "skadi";
  clients = [ "rime" ];
in
{
  config = lib.mkMerge [
    (lib.mkIf (lib.elem config.networking.hostName clients) {
      home-manager.users.${config.lab.mainUser} = {
        wayland.windowManager.hyprland = {
          settings = {
            bind = [
              "$mod_apps, s, exec, $quickterm ${lib.getExe pkgs.streamshower} -a https://streams.${config.lab.domainName}/stream-data"
            ];
          };
        };
      };
    })
    (lib.mkIf (config.networking.hostName == server) {
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
        domain = config.lab.domainName;
        environmentFile = config.sops.templates."streamserver-env".path;
      };
    })
  ];
}
