{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../common
    ./booklore.nix
    ./endpoints
    ./joplin.nix
    ./mysql.nix
    ./postfix.nix
    ./postgres.nix
    ./vaultwarden.nix
  ];

  boot.kernel.sysctl = {
    # postgres/mysql/postfix cannot bind to podman0 before its created without
    # this
    "net.ipv4.ip_nonlocal_bind" = 1;
  };

  console.colors = lib.attrValues {
    c01_black = "2e3440";
    c02_red = "bf616a";
    c03_green = "a3be8c";
    c04_yellow = "ebcb8b";
    c05_blue = "81a1c1";
    c06_magenta = "01145e";
    c07_cyan = "88c0d0";
    c08_white = "e5e9f0";
    c09_blackFg = "4c566a";
    c10_redFg = "bf616a";
    c11_greenFg = "a3be8c";
    c12_yellowFg = "ebcb8b";
    c13_blueFg = "88c0d0";
    c14_magentaFg = "b48ead";
    c15_cyanFg = "8fbcbb";
    c16_whiteFg = "eceff4";
  };

  environment = {
    systemPackages = builtins.attrValues {
      inherit (pkgs)
        mailutils
        ;
    };
  };

  home-manager = {
    users = {
      ${config.lab.mainUser} = import ../../home/logic.nix;
    };
  };

  lab = {
    booklore.enable = true;
    joplin.enable = true;
    openssh.enable = true;
    vaultwarden.enable = true;
    endpoints = {
      caddy.enable = true;
      cloudflared.enable = true;
      hosts = {
        "@".caddy.extraConfig = ''
          root * /replicated/web
          file_server browse
        '';
        "booklore".caddy.extraConfig = "reverse_proxy 127.0.0.1:6060";
        "joplin".caddy.extraConfig = "reverse_proxy 127.0.0.1:22300";
        "ssh" = {
          caddy.enable = false;
          ingress = "ssh://127.0.0.1:22";
        };
        "streams".caddy.extraConfig = "reverse_proxy 127.0.0.1:${toString config.lab.streamsPort}";
        "vaultwarden".caddy.extraConfig = ''
          reverse_proxy [::1]:${toString config.services.vaultwarden.config.ROCKET_PORT}
        '';
        "www".caddy.extraConfig = "redir https://${config.lab.domainName}{uri}";
      };
    };
    greetd = {
      enable = true;
      theme = "container=blue;window=black;border=magenta;greet=magenta;prompt=magenta;input=magenta;action=blue";
      useZshLogin = true;
    };
    streamsPort = 8181;
  };

  services = {
    pipewire.enable = false;
  };

  # users.users.${config.lab.mainUser}.extraGroups = [
  #   "dialout"
  #   "tty"
  # ];

  virtualisation = {
    podman.autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
}
