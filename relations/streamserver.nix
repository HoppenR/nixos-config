{
  pkgs,
  lib,
  config,
  ...
}:
let
  server = "skadi";
  clients = [ "rime" ];

  # TODO: recv domain name from arguments (_module.args?)
  # TODO: these pkgs should be moved into flakes into respective repository
  streamshower-pkg = pkgs.buildGoModule {
    name = "streamshower";
    pname = "streamshower";
    src = pkgs.fetchFromGitHub {
      owner = "HoppenR";
      repo = "streamshower";
      rev = "e0f4d7fe99748ccb064bf08595cb9787179bf04c";
      hash = "sha256-IQOd22sTr27/MI3/PwI3m0rfrj2uyxSxxGkxifjDs0M=";
    };
    vendorHash = "sha256-rAToVcauhNkVb2Ybz8X/piFqYGr2vCsFX/VQ3u/+6Rc=";
    meta = {
      homepage = "https://github.com/HoppenR/streamshower";
      mainProgram = "streamshower";
    };
  };
  streamserver-pkg = pkgs.buildGoModule {
    name = "streamserver";
    pname = "streamserver";
    src = pkgs.fetchFromGitHub {
      owner = "HoppenR";
      repo = "streamserver";
      rev = "c14f514a1ec627e0de1a86397d8c666e117c5028";
      hash = "sha256-kPLAEn4U6THQLVyHl3c+nZ50oXAws2Nh0kzex3uY4go=";
    };
    vendorHash = "sha256-9IHYzbAWUWxbFOPF/e2BYgcqOqXaWP+ZDPBTN0B77Ww=";
    meta = {
      homepage = "https://github.com/HoppenR/streamserver";
      mainProgram = "streamserver";
    };
  };
in
{
  config = lib.mkMerge [
    (lib.mkIf (lib.elem config.networking.hostName clients) {
      home-manager.users.christoffer = {
        wayland.windowManager.hyprland = {
          settings = {
            bind = [
              "$mod_apps, s, exec, $quickterm ${lib.getExe streamshower-pkg} -a https://streams.hoppenr.xyz/stream-data"
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
              CLIENT_ID=${config.sops.placeholder."streamserver-client-id"}
              CLIENT_SECRET=${config.sops.placeholder."streamserver-client-secret"}
            '';
          };
        };
      };
      systemd.services.streamserver = {
        description = "Go Streamserver Service";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          Environment = [
            "USER_NAME=hoppenr"
            "HOME=/var/lib/streamserver"
          ];
          EnvironmentFile = config.sops.templates."streamserver-env".path;
          ExecStart = "${lib.getExe streamserver-pkg} -a 127.0.0.1:8181 -e https://streams.hoppenr.xyz/oauth-callback";
          Restart = "always";
          StateDirectory = "streamserver";
          DynamicUser = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
        };
      };
    })
  ];
}
