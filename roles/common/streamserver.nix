{
  pkgs,
  lib,
  config,
  ...
}:
let
  # TODO: build instead of podman
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
      description = "My custom stream server";
      homepage = "https://github.com/HoppenR/streamserver";
      mainProgram = "streamserver";
    };
  };
in
{
  options.lab.streamserver = {
    enable = lib.mkEnableOption "enable streamserver lab configuration";
  };

  config = lib.mkIf config.lab.streamserver.enable {
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
        ExecStart = "${lib.getExe streamserver-pkg}";
        Restart = "always";
        StateDirectory = "streamserver";
        DynamicUser = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      };
    };
  };
}
