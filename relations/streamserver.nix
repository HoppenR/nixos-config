{
  pkgs,
  lib,
  config,
  ...
}:
let
  server = "skadi";
  clients = [ "rime" ];

  # TODO: these pkgs should be moved into flakes into respective repository
  streamshower-pkg = pkgs.buildGoModule {
    name = "streamshower";
    pname = "streamshower";
    src = pkgs.fetchFromGitHub {
      owner = "HoppenR";
      repo = "streamshower";
      rev = "af5bdabefaf1a995c068f3eecf94de14e9a711a5";
      hash = "sha256-PQLNdnwkzNmmjsIkr+LemfFcoI5lzYsL5/G0AmQZ8s0=";
    };
    vendorHash = "sha256-N7jvv1Wlt5BpMvOKdsJSX5/Vxe7SSVnDJn1qMbmrcCg=";
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
      rev = "72a9f5993ca28dc1c2642e73018cc986149105a1";
      hash = "sha256-w1DnwjFjPeOVuC6fZAoTIlZEnPW1Lu7zFdNdxkSQgfM=";
    };
    vendorHash = "sha256-uJTm4l2iCUy7HTWnkFwXzE+Ls63v2gDWSixdTutB7dA=";
    meta = {
      homepage = "https://github.com/HoppenR/streamserver";
      mainProgram = "streamserver";
    };
  };
in
{
  options.lab = {
    streamsPort = lib.mkOption {
      type = lib.types.port;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (lib.elem config.networking.hostName clients) {
      home-manager.users.${config.lab.mainUser} = {
        wayland.windowManager.hyprland = {
          settings = {
            bind = [
              "$mod_apps, s, exec, $quickterm ${lib.getExe streamshower-pkg} -a https://streams.${config.lab.domainName}/stream-data"
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

          DynamicUser = true;
          ExecStart = ''
            ${lib.getExe streamserver-pkg} \
              -a 127.0.0.1:${toString config.lab.streamsPort} \
              -e https://streams.${config.lab.domainName}/oauth-callback
          '';
          MemoryDenyWriteExecute = true;
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectProc = "invisible";
          ProtectSystem = "strict";
          Restart = "always";
          StateDirectory = "streamserver";
        };
      };
    })
  ];
}
